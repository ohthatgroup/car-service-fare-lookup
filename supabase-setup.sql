-- Car Service Fare Lookup — Supabase setup (run once in the SQL Editor)
-- Tables, security rules, vote function, and the 277 sheet fares (May 22, 2023 sheets).

create table if not exists public.fares (
  id bigint generated always as identity primary key,
  from_place text not null,
  category text not null default '',
  to_place text not null,
  price text not null,
  round_trip text,
  note text,
  origin text not null default 'sheet',
  created_at timestamptz not null default now(),
  unique (from_place, to_place)
);

create table if not exists public.proposals (
  id bigint generated always as identity primary key,
  fare_id bigint not null references public.fares(id) on delete cascade,
  new_price text not null,
  new_round_trip text,
  votes int not null default 0,
  status text not null default 'open',
  created_at timestamptz not null default now()
);

create table if not exists public.votes (
  proposal_id bigint not null references public.proposals(id) on delete cascade,
  voter_id text not null,
  created_at timestamptz not null default now(),
  primary key (proposal_id, voter_id)
);

-- At most one open proposal per fare.
create unique index if not exists proposals_one_open_per_fare
  on public.proposals (fare_id) where status = 'open';

alter table public.fares enable row level security;
alter table public.proposals enable row level security;
alter table public.votes enable row level security;

-- Anyone can read fares and open proposals, and add new fares/proposals.
-- Nobody can update or delete a fare directly: price changes happen only
-- through the cast_vote function below once a proposal reaches 10 votes.
create policy "fares read" on public.fares for select using (true);
create policy "fares add" on public.fares for insert with check (origin = 'community');
create policy "proposals read" on public.proposals for select using (true);
create policy "proposals add" on public.proposals for insert with check (status = 'open' and votes = 0);
create policy "votes none" on public.votes for select using (false);

-- One vote per voter per proposal; at 10 votes the change applies atomically.
create or replace function public.cast_vote(p_proposal_id bigint, p_voter_id text)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
  v_status text;
  v_fare bigint;
  v_price text;
  v_rt text;
begin
  select status, fare_id, new_price, new_round_trip
    into v_status, v_fare, v_price, v_rt
    from proposals where id = p_proposal_id;
  if v_status is null then raise exception 'proposal not found'; end if;
  if v_status <> 'open' then
    select votes into v_count from proposals where id = p_proposal_id;
    return v_count;
  end if;
  insert into votes (proposal_id, voter_id) values (p_proposal_id, p_voter_id)
    on conflict do nothing;
  if not found then
    select votes into v_count from proposals where id = p_proposal_id;
    return v_count;
  end if;
  update proposals set votes = votes + 1 where id = p_proposal_id
    returning votes into v_count;
  if v_count >= 10 then
    update fares set price = v_price,
                     round_trip = coalesce(v_rt, round_trip)
      where id = v_fare;
    update proposals set status = 'applied' where id = p_proposal_id;
  end if;
  return v_count;
end;
$$;

grant execute on function public.cast_vote(bigint, text) to anon, authenticated;

-- Seed: the fares from the May 22, 2023 price sheets. 277 fare rows are
-- printed, stored here as 276 routes: Borough Park's "Beth Israel" is two
-- different places (the cemetery at $105 and the hospital at $60), so they
-- are stored as "Beth Israel (Cemetery)" and "Beth Israel (Hospital)";
-- Monroe's "Nyack" is printed at the same $80 in two sections, stored once.
-- Only places are stored as routes (263): the sheets' rule rows — mini-van
-- addition brackets, hourly rates, basic stops/deliveries, and the airport
-- pickup note — are pricing rules, not places, and live in the app's logic
-- and Details text instead.
insert into public.fares (from_place, category, to_place, price, round_trip, note, origin) values
('Borough Park','Airports','Islip','$135.00','$200.00',NULL,'sheet'),
('Borough Park','Airports','JFK','$85.00','$130.00',NULL,'sheet'),
('Borough Park','Airports','LaGuardia','$85.00','$130.00',NULL,'sheet'),
('Borough Park','Airports','Newark','$85.00','$130.00',NULL,'sheet'),
('Borough Park','Airports','Teterboro','$125.00','$190.00',NULL,'sheet'),
('Borough Park','Brooklyn','1st Ave. & 69 Strt.','$28.00','$42.00',NULL,'sheet'),
('Borough Park','Brooklyn','40 8th Ave.','$30.00','$45.00',NULL,'sheet'),
('Borough Park','Brooklyn','6740 4th Ave.','$28.00','$42.00',NULL,'sheet'),
('Borough Park','Brooklyn','Bayswater','$85.00','$127.50',NULL,'sheet'),
('Borough Park','Brooklyn','Bensonhurst','$20-$24','$30-$36',NULL,'sheet'),
('Borough Park','Brooklyn','Brighton Beach','$35.00','$53.00',NULL,'sheet'),
('Borough Park','Brooklyn','Canarsie','$50.00','$75.00',NULL,'sheet'),
('Borough Park','Brooklyn','Century 21','$23.00','$35.00',NULL,'sheet'),
('Borough Park','Brooklyn','Crown Heights','$35.00','$55.00',NULL,'sheet'),
('Borough Park','Brooklyn','Down Town B''klyn','$40.00','$60.00',NULL,'sheet'),
('Borough Park','Brooklyn','Far Rockaway','$95.00','$140.00',NULL,'sheet'),
('Borough Park','Brooklyn','Five Towns','$95.00','$140.00',NULL,'sheet'),
('Borough Park','Brooklyn','Floyd Bennet Field','$40.00','$60.00',NULL,'sheet'),
('Borough Park','Brooklyn','Great Neck','$100.00','$150.00',NULL,'sheet'),
('Borough Park','Brooklyn','Green Point','$55.00','$85.00',NULL,'sheet'),
('Borough Park','Brooklyn','Kings Plaza','$37.00','$56.00',NULL,'sheet'),
('Borough Park','Brooklyn','Local','$15.00','$23.00',NULL,'sheet'),
('Borough Park','Brooklyn','Long Island City','$75.00','$115.00',NULL,'sheet'),
('Borough Park','Brooklyn','Manhattan Beach','$40.00','$60.00',NULL,'sheet'),
('Borough Park','Brooklyn','Maspeth','$75.00','$115.00',NULL,'sheet'),
('Borough Park','Brooklyn','Prospect Park','$28.00','$42.00',NULL,'sheet'),
('Borough Park','Brooklyn','Queens','$95/$105','$140/$155',NULL,'sheet'),
('Borough Park','Brooklyn','Red Hook/ Ikea','$30.00','$45.00',NULL,'sheet'),
('Borough Park','Brooklyn','Seagate','$40.00','$60.00',NULL,'sheet'),
('Borough Park','Brooklyn','Sheepshead Bay','$40.00','$60.00',NULL,'sheet'),
('Borough Park','Brooklyn','Staten Island "440"','$85.00','$130.00',NULL,'sheet'),
('Borough Park','Brooklyn','Staten Isld "Bradly"','$65.00','$100.00',NULL,'sheet'),
('Borough Park','Brooklyn','Toys R Us','$30.00','$45.00',NULL,'sheet'),
('Borough Park','Brooklyn','West 8 Sreet.','$35.00','$55.00',NULL,'sheet'),
('Borough Park','Brooklyn','Williamsburg','$40.00','$60.00',NULL,'sheet'),
('Borough Park','Catskills (printed below Cemeteries)','Parksville','$395.00','$590.00',NULL,'sheet'),
('Borough Park','Catskills (printed below Cemeteries)','Swan / White Lake','$365.00','$545.00',NULL,'sheet'),
('Borough Park','Catskills (printed below Cemeteries)','Up to Monticello','$335.00','$500.00',NULL,'sheet'),
('Borough Park','Cemeteries','Beth David','$90.00','$135.00',NULL,'sheet'),
('Borough Park','Cemeteries','Beth Israel (Cemetery)','$105.00','$160.00',NULL,'sheet'),
('Borough Park','Cemeteries','Floral Park Deans','$135.00','$200.00',NULL,'sheet'),
('Borough Park','Cemeteries','Montefiore/Chabad','$90.00','$135.00',NULL,'sheet'),
('Borough Park','Cemeteries','Mount Hebron','$80.00','$120.00',NULL,'sheet'),
('Borough Park','Cemeteries','New Montefiore','$135.00','$200.00',NULL,'sheet'),
('Borough Park','Cemeteries','Wellwood','$135.00','$200.00',NULL,'sheet'),
('Borough Park','Hospitals','Beth Israel (Hospital)','$60.00','$90.00',NULL,'sheet'),
('Borough Park','Hospitals','Beth Israel North','$85.00','$130.00',NULL,'sheet'),
('Borough Park','Hospitals','Brookdale','$50.00','$75.00',NULL,'sheet'),
('Borough Park','Hospitals','Brooklyn','$45.00','$70.00',NULL,'sheet'),
('Borough Park','Hospitals','Columbia Presb.','$95.00','$145.00',NULL,'sheet'),
('Borough Park','Hospitals','Joint Disease','$60.00','$90.00',NULL,'sheet'),
('Borough Park','Hospitals','L.I.C.H.','$45.00','$70.00',NULL,'sheet'),
('Borough Park','Hospitals','L.I.J. / Northshore','$95.00','$145.00',NULL,'sheet'),
('Borough Park','Hospitals','Lenox Hill','$75.00','$115.00',NULL,'sheet'),
('Borough Park','Hospitals','Lutheran','$25.00','$38.00',NULL,'sheet'),
('Borough Park','Hospitals','Memorial','$75.00','$115.00',NULL,'sheet'),
('Borough Park','Hospitals','Methodist','$30.00','$45.00',NULL,'sheet'),
('Borough Park','Hospitals','Montefiore','$105.00','$160.00',NULL,'sheet'),
('Borough Park','Hospitals','Mount Sinai','$90.00','$135.00',NULL,'sheet'),
('Borough Park','Hospitals','NY Cornnell','$75.00','$115.00',NULL,'sheet'),
('Borough Park','Hospitals','NYU','$65.00','$100.00',NULL,'sheet'),
('Borough Park','Hospitals','Riverdale','$105.00','$160.00',NULL,'sheet'),
('Borough Park','Hospitals','St. Vincent','$60.00','$90.00',NULL,'sheet'),
('Borough Park','Hospitals','Staten Island','$65.00','$100.00',NULL,'sheet'),
('Borough Park','Hospitals','Westchester Medical','$160.00','$240.00',NULL,'sheet'),
('Borough Park','Long Distance','Bayonne','$75.00','$115.00',NULL,'sheet'),
('Borough Park','Long Distance','Elizabeth','$85.00','$130.00',NULL,'sheet'),
('Borough Park','Long Distance','Engelwood','$115.00','$175.00',NULL,'sheet'),
('Borough Park','Long Distance','Garden City L.I.','$115.00','$175.00',NULL,'sheet'),
('Borough Park','Long Distance','Garden St Mall','$135.00','$200.00',NULL,'sheet'),
('Borough Park','Long Distance','Jersry Garden','$85.00','$130.00',NULL,'sheet'),
('Borough Park','Long Distance','Kasho','$160.00','$240.00',NULL,'sheet'),
('Borough Park','Long Distance','Lakewood','$195.00','$295.00',NULL,'sheet'),
('Borough Park','Long Distance','Monroe','$195.00','$295.00',NULL,'sheet'),
('Borough Park','Long Distance','Monsey','$170.00','$255.00',NULL,'sheet'),
('Borough Park','Long Distance','Morristown','$160.00','$240.00',NULL,'sheet'),
('Borough Park','Long Distance','Mount Kisko','$170.00','$255.00',NULL,'sheet'),
('Borough Park','Long Distance','New Square','$170.00','$255.00',NULL,'sheet'),
('Borough Park','Long Distance','Palisiades Mall','$160.00','$240.00',NULL,'sheet'),
('Borough Park','Long Distance','Passaic','$115.00','$175.00',NULL,'sheet'),
('Borough Park','Long Distance','Peekskill','$195.00','$295.00',NULL,'sheet'),
('Borough Park','Long Distance','Somerest','$170.00','$255.00',NULL,'sheet'),
('Borough Park','Long Distance','Stamford CT','$170.00','$255.00',NULL,'sheet'),
('Borough Park','Long Distance','Teaneck','$125.00','$190.00',NULL,'sheet'),
('Borough Park','Long Distance','Union City','$100.00','$150.00',NULL,'sheet'),
('Borough Park','Long Distance','Union, / Linden','$85/$90','$130/$135',NULL,'sheet'),
('Borough Park','Long Distance','White Planes','$160.00','$240.00',NULL,'sheet'),
('Borough Park','Long Distance','Yonkers','$115.00','$175.00',NULL,'sheet'),
('Borough Park','Manhattan','E&W 101St.~ 150St.','$90.00','$135.00',NULL,'sheet'),
('Borough Park','Manhattan','E&W 14 St. ~ 30 St.','$60.00','$90.00',NULL,'sheet'),
('Borough Park','Manhattan','E&W 151St. ~ 200St.','$95.00','$145.00',NULL,'sheet'),
('Borough Park','Manhattan','E&W 31St. ~ 50St.','$65.00','$100.00',NULL,'sheet'),
('Borough Park','Manhattan','E&W 51St.~ 79St.','$75.00','$115.00',NULL,'sheet'),
('Borough Park','Manhattan','E&W 80St.~ 100St.','$80.00','$120.00',NULL,'sheet'),
('Borough Park','Manhattan','Lower Eastside','$55.00','$83.00',NULL,'sheet'),
('Borough Park','Manhattan','Riverdale/Bronx','$105.00','$160.00',NULL,'sheet'),
('Borough Park','Manhattan','Wall Street area','$55.00','$83.00',NULL,'sheet'),
('Borough Park','Manhattan','Washngtn Hights','$95.00','$145.00',NULL,'sheet'),
('Lakewood','Airports','John F. Kennedy (JFK)','$240.00',NULL,NULL,'sheet'),
('Lakewood','Airports','LaGuardia (LGA)','$240.00',NULL,NULL,'sheet'),
('Lakewood','Airports','Newark (EWR)','$135.00',NULL,NULL,'sheet'),
('Lakewood','Airports','Philadefiphia (PHL)','$215.00',NULL,NULL,'sheet'),
('Lakewood','Long distance','Boroughpark','$200.00',NULL,NULL,'sheet'),
('Lakewood','Long distance','Bronx','$280.00',NULL,NULL,'sheet'),
('Lakewood','Long distance','Monroe','$230.00',NULL,NULL,'sheet'),
('Lakewood','Long distance','Monsey / New Square','$250.00',NULL,NULL,'sheet'),
('Lakewood','Long distance','NYC','$200.00',NULL,NULL,'sheet'),
('Lakewood','Long distance','Williamsburg','$280.00',NULL,NULL,'sheet'),
('Lakewood','Mountains','Ellenville','$350.00',NULL,NULL,'sheet'),
('Lakewood','Mountains','Fallsburg','$350.00',NULL,NULL,'sheet'),
('Lakewood','Mountains','Fleishmman''s','$450.00',NULL,NULL,'sheet'),
('Lakewood','Mountains','Kerhonkson','$380.00',NULL,NULL,'sheet'),
('Lakewood','Mountains','Kiamesha (Gibbers)','$350.00',NULL,NULL,'sheet'),
('Lakewood','Mountains','Lapidus (White lake)','$380.00',NULL,NULL,'sheet'),
('Lakewood','Mountains','Liberty','$380.00',NULL,NULL,'sheet'),
('Lakewood','Mountains','Loch Sheldrake','$375.00',NULL,NULL,'sheet'),
('Lakewood','Mountains','Monticello','$350.00',NULL,NULL,'sheet'),
('Lakewood','Mountains','Napanach','$350.00',NULL,NULL,'sheet'),
('Lakewood','Mountains','Swan Lake','$380.00',NULL,NULL,'sheet'),
('Lakewood','Mountains','Woodbourne','$360.00',NULL,NULL,'sheet'),
('Lakewood','Mountains','Woodrige / Dairyland','$350.00',NULL,NULL,'sheet'),
('Monroe','Airports','Albany (Colonie NY)','$245.00',NULL,NULL,'sheet'),
('Monroe','Airports','John F. Kennedy (JFK)','$195.00',NULL,NULL,'sheet'),
('Monroe','Airports','LaGuardia (LGA)','$165.00',NULL,NULL,'sheet'),
('Monroe','Airports','Newark (EWR)','$140.00',NULL,NULL,'sheet'),
('Monroe','Airports','Philadefiphia (PHL)','$360.00',NULL,NULL,'sheet'),
('Monroe','Airports','Steward (Winsor NY)','$60.00',NULL,NULL,'sheet'),
('Monroe','Cemetaries','Beth David','$195.00',NULL,NULL,'sheet'),
('Monroe','Cemetaries','Beth Moses (West Babylon NY)','$220.00',NULL,NULL,'sheet'),
('Monroe','Cemetaries','Floral Park (Dean Rhode NJ)','$220.00',NULL,NULL,'sheet'),
('Monroe','Cemetaries','Ohel Chabad (Queens)','$195.00',NULL,NULL,'sheet'),
('Monroe','Hispitals','Cleavland Medical Center (OH)','$1,020.00',NULL,NULL,'sheet'),
('Monroe','Hispitals','Colubia Presbyterian','$125.00',NULL,NULL,'sheet'),
('Monroe','Hispitals','Good Samaritan (Sufferen NY)','$65.00',NULL,NULL,'sheet'),
('Monroe','Hispitals','Hackensack Medical Center','$100.00',NULL,NULL,'sheet'),
('Monroe','Hispitals','Montefiore Medical Center (Brx)','$125.00',NULL,NULL,'sheet'),
('Monroe','Hispitals','Nyack','$80.00',NULL,NULL,'sheet'),
('Monroe','Hispitals','Valley Woman & C (Paramus NJ)','$80.00',NULL,NULL,'sheet'),
('Monroe','Hispitals','Warwick / St. Antthony','$60.00',NULL,NULL,'sheet'),
('Monroe','Hispitals','Westchester Medical Center','$110.00',NULL,NULL,'sheet'),
('Monroe','Long distance','American Drea Mall','$130.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Bear mountains','$40.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Bloomingburg','$60.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Borough Park','$210.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Brewster','$115.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Bronx','$125.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Chester (Neitre)','$40.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Clifton','$130.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Cornwell','$40.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Crown Heights','$200.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Flatbush','$210.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Garden state mall (RT. 4)','$100.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Goshen','$45.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Hackensack NJ','$100.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Hopewell Jnct.','$120.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Jersey city','$150.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Kiryas Kasho (Bedford Hills NY)','$115.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Kiryas Pupa/Cemetary (Ossining NY)','$110.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Lake Walch','$65.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Lakewood / Toms river / Howell','$260.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Middletown','$55.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Monsey','$70.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Montgomrery','$65.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Mt. Kisko (Neitre)','$110.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Nanuet','$70.00',NULL,NULL,'sheet'),
('Monroe','Long distance','New City','$70.00',NULL,NULL,'sheet'),
('Monroe','Long distance','New Square','$65.00',NULL,NULL,'sheet'),
('Monroe','Long distance','New Winsor','$50.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Newburg','$75.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Orangeburg','$80.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Palisades Mall','$75.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Paramus','$80.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Perl Rive','$80.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Platsburg (City)','$570.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Platsburg (Exit 42 on I87)','$620.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Pomona','$70.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Possiac NJ','$105.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Queens Yeshiva','$165.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Ramsey','$75.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Ridgewood','$80.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Round Top','$175.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Scarsdale','$115.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Sea gate','$220.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Staten Island','$195.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Sufferen','$65.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Teaneck','$110.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Tuxedo','$60.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Washingtonville','$35.00',NULL,NULL,'sheet'),
('Monroe','Long distance','West Havestraw','$70.00',NULL,NULL,'sheet'),
('Monroe','Long distance','White Plains','$110.00',NULL,NULL,'sheet'),
('Monroe','Long distance','Williamsburg','$180.00',NULL,NULL,'sheet'),
('Monroe','Mountains','Ellenville','$105.00',NULL,NULL,'sheet'),
('Monroe','Mountains','Fallsburg','$105.00',NULL,NULL,'sheet'),
('Monroe','Mountains','Fleishmman''s','$200.00',NULL,NULL,'sheet'),
('Monroe','Mountains','Gibbers / Kiamesha','$105.00',NULL,NULL,'sheet'),
('Monroe','Mountains','Kerhonkson','$125.00',NULL,NULL,'sheet'),
('Monroe','Mountains','Lapidus (White lake)','$125.00',NULL,NULL,'sheet'),
('Monroe','Mountains','Liberty','$125.00',NULL,NULL,'sheet'),
('Monroe','Mountains','Loch Sheldrake','$120.00',NULL,NULL,'sheet'),
('Monroe','Mountains','Monticello','$105.00',NULL,NULL,'sheet'),
('Monroe','Mountains','Napanach','$105.00',NULL,NULL,'sheet'),
('Monroe','Mountains','Swan Lake','$125.00',NULL,NULL,'sheet'),
('Monroe','Mountains','Woodbourne','$110.00',NULL,NULL,'sheet'),
('Monroe','Mountains','Woodrige / Dairyland','$105.00',NULL,NULL,'sheet'),
('Monroe','NYC (up to)','30th Street','$165.00',NULL,NULL,'sheet'),
('Monroe','NYC (up to)','55th Street','$150.00',NULL,NULL,'sheet'),
('Monroe','NYC (up to)','80th Strett','$125.00',NULL,NULL,'sheet'),
('Monroe','NYC (up to)','Lower Eastside / Westside','$175.00',NULL,NULL,'sheet'),
('Monsey','Airports','Albany (Colonie NY)','$290.00',NULL,NULL,'sheet'),
('Monsey','Airports','John F. Kennedy (JFK)','$200.00',NULL,NULL,'sheet'),
('Monsey','Airports','LaGuardia (LGA)','$180.00',NULL,NULL,'sheet'),
('Monsey','Airports','Newark (EWR)','$140.00',NULL,NULL,'sheet'),
('Monsey','Airports','Philadefiphia (PHL)','$330.00',NULL,NULL,'sheet'),
('Monsey','Airports','Steward (Winsor NY)','$90.00',NULL,NULL,'sheet'),
('Monsey','Cemetaries','Beth David','$195.00',NULL,NULL,'sheet'),
('Monsey','Cemetaries','Beth Moses (West Babylon NY)','$220.00',NULL,NULL,'sheet'),
('Monsey','Cemetaries','Floral Park (Dean Rhode NJ)','$220.00',NULL,NULL,'sheet'),
('Monsey','Cemetaries','Ohel Chabad (Queens)','$195.00',NULL,NULL,'sheet'),
('Monsey','Hispitals','Cleavland Medical Center (OH)','$1,050.00',NULL,NULL,'sheet'),
('Monsey','Hispitals','Colubia Presbyterian','$100.00',NULL,NULL,'sheet'),
('Monsey','Hispitals','Good Samaritan (Sufferen NY)','$40.00',NULL,NULL,'sheet'),
('Monsey','Hispitals','Hackensack Medical Center','$75.00',NULL,NULL,'sheet'),
('Monsey','Hispitals','Montefiore Medical Center (Brx)','$100.00',NULL,NULL,'sheet'),
('Monsey','Hispitals','Nyack','$55.00',NULL,NULL,'sheet'),
('Monsey','Hispitals','Valley Woman & C (Paramus NJ)','$55.00',NULL,NULL,'sheet'),
('Monsey','Hispitals','Warwick / St. Antthony','$80.00',NULL,NULL,'sheet'),
('Monsey','Hispitals','Westchester Medical Center','$85.00',NULL,NULL,'sheet'),
('Monsey','Long distance','American Drea Mall','$130.00',NULL,NULL,'sheet'),
('Monsey','Long distance','Borough park','$170.00',NULL,NULL,'sheet'),
('Monsey','Long distance','Bronx','$100.00',NULL,NULL,'sheet'),
('Monsey','Long distance','Crown Height','$170.00',NULL,NULL,'sheet'),
('Monsey','Long distance','Flatbush','$185.00',NULL,NULL,'sheet'),
('Monsey','Long distance','Garden state mall (RT. 4)','$100.00',NULL,NULL,'sheet'),
('Monsey','Long distance','Jersey city','$140.00',NULL,NULL,'sheet'),
('Monsey','Long distance','Kiryas Kasho (Bedford Hills NY)','$115.00',NULL,NULL,'sheet'),
('Monsey','Long distance','Kiryas Pupa/Cemetary (Ossinir','$110.00',NULL,NULL,'sheet'),
('Monsey','Long distance','Lakewood','$135.00',NULL,NULL,'sheet'),
('Monsey','Long distance','Monroe','$70.00',NULL,NULL,'sheet'),
('Monsey','Long distance','Mt. Kisko (Neitre)','$110.00',NULL,NULL,'sheet'),
('Monsey','Long distance','Palisades Mall','$55.00',NULL,NULL,'sheet'),
('Monsey','Long distance','Possiac NJ','$130.00',NULL,NULL,'sheet'),
('Monsey','Long distance','Queens Yeshiva','$140.00',NULL,NULL,'sheet'),
('Monsey','Long distance','Sea gate','$195.00',NULL,NULL,'sheet'),
('Monsey','Long distance','Staten island','$170.00',NULL,NULL,'sheet'),
('Monsey','Long distance','Teaneck','$90.00',NULL,NULL,'sheet'),
('Monsey','Long distance','Williamsburg','$155.00',NULL,NULL,'sheet'),
('Monsey','Mountains','Ellenville','$140.00',NULL,NULL,'sheet'),
('Monsey','Mountains','Fallsburg','$140.00',NULL,NULL,'sheet'),
('Monsey','Mountains','Fleishmman''s','$235.00',NULL,NULL,'sheet'),
('Monsey','Mountains','Gibbers / Kiamesha','$140.00',NULL,NULL,'sheet'),
('Monsey','Mountains','Kerhonkson','$150.00',NULL,NULL,'sheet'),
('Monsey','Mountains','Lapidus (White lake)','$150.00',NULL,NULL,'sheet'),
('Monsey','Mountains','Liberty','$150.00',NULL,NULL,'sheet'),
('Monsey','Mountains','Loch Sheldrake','$145.00',NULL,NULL,'sheet'),
('Monsey','Mountains','Monticello','$140.00',NULL,NULL,'sheet'),
('Monsey','Mountains','Napanach','$140.00',NULL,NULL,'sheet'),
('Monsey','Mountains','Swan Lake','$150.00',NULL,NULL,'sheet'),
('Monsey','Mountains','Woodbourne','$140.00',NULL,NULL,'sheet'),
('Monsey','Mountains','Woodrige / Dairyland','$140.00',NULL,NULL,'sheet'),
('Monsey','NYC up to','30th Street','$140.00',NULL,NULL,'sheet'),
('Monsey','NYC up to','55th Street','$125.00',NULL,NULL,'sheet'),
('Monsey','NYC up to','80th Strett','$100.00',NULL,NULL,'sheet'),
('Monsey','NYC up to','Lower Eastside / Westside','$150.00',NULL,NULL,'sheet')
on conflict (from_place, to_place) do nothing;
