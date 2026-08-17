-- ==========================================================
-- LinguaNote — ссылки в домашке + вопросы от студентов
-- Выполни в Supabase → SQL Editor → New query → Run
-- ==========================================================

alter table homework add column if not exists link text;
alter table homework add column if not exists is_question boolean not null default false;

create policy "homework_student_insert" on homework for insert
  with check (exists (select 1 from students s where s.id = homework.student_id and s.user_id = auth.uid()));
