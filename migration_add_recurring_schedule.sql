-- ==========================================================
-- LinguaNote — регулярное расписание
-- Выполни в Supabase → SQL Editor → New query → Run
-- (для новых проектов уже включено в основной schema.sql)
-- ==========================================================

alter table students add column if not exists recurring_weekdays int[];
alter table students add column if not exists recurring_time text;
