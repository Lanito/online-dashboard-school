-- ==========================================================
-- LinguaNote — добавление раздела "Планы на будущее"
-- Выполни этот файл в Supabase → SQL Editor → New query → Run
-- (для проектов, где schema.sql уже был запущен ранее)
-- ==========================================================

create table plans (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references students(id) on delete cascade not null,
  text text not null,
  done boolean not null default false,
  created_at timestamptz default now()
);

create index on plans(student_id);

alter table plans enable row level security;

create policy "plans_teacher_all" on plans for all
  using (exists (select 1 from students s where s.id = plans.student_id and s.teacher_id = auth.uid()))
  with check (exists (select 1 from students s where s.id = plans.student_id and s.teacher_id = auth.uid()));

create policy "plans_student_select" on plans for select
  using (exists (select 1 from students s where s.id = plans.student_id and s.user_id = auth.uid()));
