-- ==========================================================
-- LinguaNote — заметки "О студенте" + шаблоны быстрых заметок
-- Выполни в Supabase → SQL Editor → New query → Run
-- ==========================================================

alter table students add column if not exists about_notes text;

create table note_templates (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid references auth.users not null,
  category text not null check (category in ('grammar','pronunciation','vocabulary')),
  text text not null,
  created_at timestamptz default now()
);
create index on note_templates(teacher_id);
alter table note_templates enable row level security;

create policy "note_templates_teacher_all" on note_templates for all
  using (teacher_id = auth.uid())
  with check (teacher_id = auth.uid());
