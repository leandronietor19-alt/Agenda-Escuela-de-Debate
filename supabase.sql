-- =====================================================================
--  Agenda Escuela de Debate · Comillas
--  Script de base de datos para Supabase.
--  Pégalo entero en  SQL Editor  ->  New query  y pulsa  Run.
--  Se puede ejecutar más de una vez sin romper nada.
-- =====================================================================

-- 1. Tabla de actividades
create table if not exists public.activities (
  id          uuid primary key default gen_random_uuid(),
  title       text not null check (char_length(title) between 1 and 200),
  grp         text not null default 'otros'
              check (grp in ('debate','mun','diplomacia','otros')),
  date        date not null,
  deadline    date not null,
  place       text not null default '',
  notes       text not null default '',
  created_by  uuid default auth.uid(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- 2. Tabla de tareas (cada tarea pertenece a una actividad)
create table if not exists public.todos (
  id           uuid primary key default gen_random_uuid(),
  activity_id  uuid not null references public.activities(id) on delete cascade,
  text         text not null check (char_length(text) between 1 and 300),
  done         boolean not null default false,
  position     integer not null default 0,
  created_at   timestamptz not null default now()
);
create index if not exists todos_activity_idx on public.todos(activity_id);

-- 3. Mantener updated_at al día
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$ begin new.updated_at = now(); return new; end $$;
drop trigger if exists activities_touch on public.activities;
create trigger activities_touch before update on public.activities
for each row execute function public.touch_updated_at();

-- 4. Seguridad: solo usuarios con sesión iniciada pueden leer y escribir
alter table public.activities enable row level security;
alter table public.todos      enable row level security;

drop policy if exists "miembros leen y editan actividades" on public.activities;
create policy "miembros leen y editan actividades" on public.activities
  for all to authenticated using (true) with check (true);

drop policy if exists "miembros leen y editan tareas" on public.todos;
create policy "miembros leen y editan tareas" on public.todos
  for all to authenticated using (true) with check (true);

-- 5. Tiempo real: avisar a la web cuando cambie algo
do $$
begin
  begin alter publication supabase_realtime add table public.activities; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.todos;      exception when duplicate_object then null; end;
end $$;
