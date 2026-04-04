-- Dev seed data: a few people across sections and statuses

INSERT INTO person (id, first_name, last_name, section_id, created_at, updated_at) VALUES
    (1, 'Anna', 'Andersson', 1, unixepoch(), unixepoch()),
    (2, 'Björn', 'Björkman', 7, unixepoch(), unixepoch()),
    (3, 'Cecilia', 'Carlsson', 4, unixepoch(), unixepoch()),
    (4, 'David', 'Dahl', 11, unixepoch(), unixepoch()),
    (5, 'Eva', 'Eriksson', 6, unixepoch(), unixepoch());

INSERT INTO person_instrument (person_id, instrument_id) VALUES
    (1, 1),   -- Anna: Tvärflöjt
    (2, 17),  -- Björn: Trumpet
    (3, 6),   -- Cecilia: Klarinett
    (4, 22),  -- David: Slagverk
    (5, 15);  -- Eva: Valthorn

-- Anna and David are current members
INSERT INTO membership_period (person_id, start_date) VALUES
    (1, '2020-01-01'),
    (4, '2021-09-01');

-- Björn is a former member
INSERT INTO membership_period (person_id, start_date, end_date) VALUES
    (2, '2018-01-01', '2023-06-30');

-- Eva has rejoined (two periods)
INSERT INTO membership_period (person_id, start_date, end_date) VALUES
    (5, '2015-01-01', '2019-12-31');
INSERT INTO membership_period (person_id, start_date) VALUES
    (5, '2022-01-01');

-- Cecilia has no membership periods (substitute/non-member)
