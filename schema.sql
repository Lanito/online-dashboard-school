-- ==========================================================
-- LinguaNote — схема базы данных для Supabase
-- Скопируй весь этот файл и выполни в Supabase → SQL Editor → New query → Run
-- ==========================================================

create extension if not exists pgcrypto;

-- Профиль пользователя (и преподавателя, и студента)
create table profiles (
  id uuid references auth.users on delete cascade primary key,
  role text not null check (role in ('teacher','student')),
  name text not null,
  created_at timestamptz default now()
);

-- Карточка студента в списке преподавателя.
-- user_id пустой, пока студент не зарегистрировался по коду приглашения.
create table students (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid references auth.users not null,
  user_id uuid references auth.users,
  name text not null,
  invite_code text unique not null,
  lesson_number int not null default 1,
  next_lesson_at timestamptz,
  paid_lessons int not null default 0,
  created_at timestamptz default now()
);

-- Урок (активный, пока преподаватель его не завершит)
create table lessons (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references students(id) on delete cascade not null,
  lesson_number int not null,
  status text not null default 'active' check (status in ('active','completed')),
  started_at timestamptz default now(),
  ended_at timestamptz
);

-- Заметка внутри урока
create table notes (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid references lessons(id) on delete cascade not null,
  category text not null check (category in ('grammar','pronunciation','vocabulary')),
  text text not null,
  tag text,
  created_at timestamptz default now()
);

-- Планы на будущее — темы, которые преподаватель хочет разобрать со студентом
create table plans (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references students(id) on delete cascade not null,
  text text not null,
  done boolean not null default false,
  created_at timestamptz default now()
);

-- Домашнее задание — отдельно от "планов".
-- План — тема, которую разберёт преподаватель на уроке.
-- Домашка — то, что должен сделать сам студент; он же отмечает "выполнено".
create table homework (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references students(id) on delete cascade not null,
  text text not null,
  done boolean not null default false,
  created_at timestamptz default now()
);

-- История пополнений оплаты
create table payments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references students(id) on delete cascade not null,
  lessons_added int not null,
  note text,
  created_at timestamptz default now()
);

create index on students(teacher_id);
create index on students(user_id);
create index on lessons(student_id);
create index on notes(lesson_id);
create index on plans(student_id);
create index on homework(student_id);
create index on payments(student_id);

-- ==========================================================
-- Row Level Security — каждый видит только своё
-- ==========================================================

alter table profiles enable row level security;
alter table students enable row level security;
alter table lessons enable row level security;
alter table notes enable row level security;
alter table plans enable row level security;
alter table homework enable row level security;
alter table payments enable row level security;

-- profiles: пользователь видит и редактирует только свою запись
create policy "profiles_select_own" on profiles for select using (id = auth.uid());
create policy "profiles_insert_own" on profiles for insert with check (id = auth.uid());
create policy "profiles_update_own" on profiles for update using (id = auth.uid());

-- students: преподаватель управляет своими студентами полностью
create policy "students_teacher_all" on students for all
  using (teacher_id = auth.uid())
  with check (teacher_id = auth.uid());

-- students: студент видит только свою собственную карточку
create policy "students_student_select" on students for select
  using (user_id = auth.uid());

-- lessons: преподаватель управляет уроками своих студентов
create policy "lessons_teacher_all" on lessons for all
  using (exists (select 1 from students s where s.id = lessons.student_id and s.teacher_id = auth.uid()))
  with check (exists (select 1 from students s where s.id = lessons.student_id and s.teacher_id = auth.uid()));

-- lessons: студент видит только свои уроки (без права редактировать)
create policy "lessons_student_select" on lessons for select
  using (exists (select 1 from students s where s.id = lessons.student_id and s.user_id = auth.uid()));

-- notes: преподаватель управляет заметками своих студентов
create policy "notes_teacher_all" on notes for all
  using (exists (select 1 from lessons l join students s on s.id = l.student_id where l.id = notes.lesson_id and s.teacher_id = auth.uid()))
  with check (exists (select 1 from lessons l join students s on s.id = l.student_id where l.id = notes.lesson_id and s.teacher_id = auth.uid()));

-- notes: студент видит только свои заметки (без права редактировать)
create policy "notes_student_select" on notes for select
  using (exists (select 1 from lessons l join students s on s.id = l.student_id where l.id = notes.lesson_id and s.user_id = auth.uid()));

-- plans: преподаватель управляет планами своих студентов
create policy "plans_teacher_all" on plans for all
  using (exists (select 1 from students s where s.id = plans.student_id and s.teacher_id = auth.uid()))
  with check (exists (select 1 from students s where s.id = plans.student_id and s.teacher_id = auth.uid()));

-- plans: студент видит свои планы (без права редактировать)
create policy "plans_student_select" on plans for select
  using (exists (select 1 from students s where s.id = plans.student_id and s.user_id = auth.uid()));

-- homework: преподаватель управляет домашками своих студентов
create policy "homework_teacher_all" on homework for all
  using (exists (select 1 from students s where s.id = homework.student_id and s.teacher_id = auth.uid()))
  with check (exists (select 1 from students s where s.id = homework.student_id and s.teacher_id = auth.uid()));

-- homework: студент видит и может отмечать выполненными свои задания
create policy "homework_student_select" on homework for select
  using (exists (select 1 from students s where s.id = homework.student_id and s.user_id = auth.uid()));
create policy "homework_student_update" on homework for update
  using (exists (select 1 from students s where s.id = homework.student_id and s.user_id = auth.uid()))
  with check (exists (select 1 from students s where s.id = homework.student_id and s.user_id = auth.uid()));

-- payments: преподаватель управляет историей оплаты своих студентов
create policy "payments_teacher_all" on payments for all
  using (exists (select 1 from students s where s.id = payments.student_id and s.teacher_id = auth.uid()))
  with check (exists (select 1 from students s where s.id = payments.student_id and s.teacher_id = auth.uid()));

-- payments: студент видит историю своей оплаты
create policy "payments_student_select" on payments for select
  using (exists (select 1 from students s where s.id = payments.student_id and s.user_id = auth.uid()));

-- ==========================================================
-- Функция присоединения студента по коду приглашения.
-- SECURITY DEFINER: обходит RLS безопасно, только для авторизованных пользователей.
-- ==========================================================

create or replace function public.join_with_code(code text)
returns table (id uuid, name text, lesson_number int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Необходимо войти в систему';
  end if;

  select students.id into v_student_id
  from students
  where students.invite_code = code and students.user_id is null;

  if v_student_id is null then
    raise exception 'Код не найден или уже использован';
  end if;

  update students set user_id = auth.uid() where students.id = v_student_id;

  return query select students.id, students.name, students.lesson_number
    from students where students.id = v_student_id;
end;
$$;

revoke all on function public.join_with_code(text) from public;
grant execute on function public.join_with_code(text) to authenticated;
