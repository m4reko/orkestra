INSERT INTO person (first_name, last_name, email, phone, street_address, postal_code, city, section_id, metadata, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
RETURNING id
