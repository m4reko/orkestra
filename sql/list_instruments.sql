SELECT i.id, i.name, s.name
FROM instrument i
JOIN section s ON i.section_id = s.id
ORDER BY s.name, i.name
