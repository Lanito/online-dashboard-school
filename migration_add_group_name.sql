-- ==========================================================
-- LinguaNote — группы студентов
-- Выполни в Supabase → SQL Editor → New query → Run
-- ==========================================================

alter table students add column if not exists group_name text;
