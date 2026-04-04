-- Initial schema: sections, instruments, persons, membership

CREATE TABLE section (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE instrument (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    section_id INTEGER NOT NULL REFERENCES section(id)
);

CREATE TABLE person (
    id INTEGER PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    street_address TEXT,
    postal_code TEXT,
    city TEXT,
    section_id INTEGER REFERENCES section(id),
    metadata TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE TABLE person_instrument (
    person_id INTEGER NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    instrument_id INTEGER NOT NULL REFERENCES instrument(id),
    PRIMARY KEY (person_id, instrument_id)
);

CREATE TABLE membership_period (
    id INTEGER PRIMARY KEY,
    person_id INTEGER NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    start_date TEXT NOT NULL,
    end_date TEXT
);

-- Seed sections
INSERT INTO section (id, name) VALUES
    (1, 'Flöjt'),
    (2, 'Oboe'),
    (3, 'Fagott'),
    (4, 'Klarinett'),
    (5, 'Saxofon'),
    (6, 'Valthorn'),
    (7, 'Trumpet'),
    (8, 'Trombon'),
    (9, 'Euphonium'),
    (10, 'Tuba'),
    (11, 'Slagverk'),
    (12, 'Kontrabas/Harpa/Piano'),
    (13, 'Dirigent');

-- Seed instruments
INSERT INTO instrument (name, section_id) VALUES
    ('Tvärflöjt', 1),
    ('Piccolaflöjt', 1),
    ('Oboe', 2),
    ('Engelskt horn', 2),
    ('Fagott', 3),
    ('Klarinett', 4),
    ('Essklarinett', 4),
    ('Altklarinett', 4),
    ('Basklarinett', 4),
    ('Kontrabasklarinett', 4),
    ('Sopransaxofon', 5),
    ('Altsaxofon', 5),
    ('Tenorsaxofon', 5),
    ('Barytonsaxofon', 5),
    ('Valthorn', 6),
    ('Kornett', 7),
    ('Trumpet', 7),
    ('Trombon', 8),
    ('Bastrombon', 8),
    ('Euphonium', 9),
    ('Tuba', 10),
    ('Slagverk', 11),
    ('Kontrabas', 12),
    ('Harpa', 12),
    ('Piano', 12),
    ('Dirigering', 13);
