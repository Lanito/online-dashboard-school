-- ==========================================================
-- LinguaNote — добавление: домашние задания, оплата, расписание
-- Выполни в Supabase → SQL Editor → New query → Run
-- (если schema.sql уже был запущен ранее; для новых проектов
-- эти изменения уже включены в основной schema.sql)
-- ==========================================================

-- Расписание следующего урока + учёт оплаченных занятий
alter table students add column if not exists next_lesson_at timestamptz;
alter table students add column if not exists paid_lessons int not null default 0;

-- Домашнее задание — отдельно от "планов".
-- Разница: план — тема, которую разберёт преподаватель на уроке.
-- Домашка — то, что должен сделать сам студент, и он же отмечает "выполнено".
create table homework (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references students(id) on delete cascade not null,
  text text not null,
  done boolean not null default false,
  created_at timestamptz default now()
);
create index on homework(student_id);
alter table homework enable row level security;

create policy "homework_teacher_all" on homework for all
  using (exists (select 1 from students s where s.id = homework.student_id and s.teacher_id = auth.uid()))
  with check (exists (select 1 from students s where s.id = homework.student_id and s.teacher_id = auth.uid()));

-- студент видит свои домашние задания...
create policy "homework_student_select" on homework for select
  using (exists (select 1 from students s where s.id = homework.student_id and s.user_id = auth.uid()));

-- ...и может отмечать их выполненными (менять только запись, привязанную к себе)
create policy "homework_student_update" on homework for update
  using (exists (select 1 from students s where s.id = homework.student_id and s.user_id = auth.uid()))
  with check (exists (select 1 from students s where s.id = homework.student_id and s.user_id = auth.uid()));

-- История пополнений оплаты (для записи, кто когда оплатил сколько занятий)
create table payments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references students(id) on delete cascade not null,
  lessons_added int not null,
  note text,
  created_at timestamptz default now()
);
create index on payments(student_id);
alter table payments enable row level security;

create policy "payments_teacher_all" on payments for all
  using (exists (select 1 from students s where s.id = payments.student_id and s.teacher_id = auth.uid()))
  with check (exists (select 1 from students s where s.id = payments.student_id and s.teacher_id = auth.uid()));

create policy "payments_student_select" on payments for select
  using (exists (select 1 from students s where s.id = payments.student_id and s.user_id = auth.uid()));
