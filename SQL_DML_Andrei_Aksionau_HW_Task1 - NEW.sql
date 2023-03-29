with
film_data AS
(
    SELECT 'I AM LEGEND'  AS title, 2007 AS release_year, 'english' AS language_name, 4.99 AS rental_rate, 1 AS rental_duration
    UNION ALL
    SELECT 'INTERSTELLAR'  AS title, 2014 AS release_year, 'english' AS language_name, 9.99 AS rental_rate, 2 AS rental_duration
    UNION ALL
    SELECT 'JOKER' AS title, 2019 AS release_year, 'english' AS language_name, 19.99 AS rental_rate, 3 AS rental_duration
),
actor_data AS
(
    SELECT 'I AM LEGEND'  AS title, 'Will' AS first_name,'Smith' AS last_name, 2007 AS release_year
    UNION ALL 
    SELECT 'I AM LEGEND'  AS title, 'Alice' AS first_name, 'Braga' AS last_name, 2007 AS release_year
    UNION ALL
    SELECT 'I AM LEGEND'  AS title, 'Dash' AS first_name,'Mihok' AS last_name, 2007 AS release_year
    union all
    SELECT 'INTERSTELLAR'  AS title, 'Matthew' AS first_name, 'McConaughey' AS last_name, 2014 AS release_year
    UNION ALL
    SELECT 'INTERSTELLAR'  AS title, 'Anne' AS first_name, 'Hathaway' AS last_name, 2014 AS release_year
    UNION ALL
    SELECT 'INTERSTELLAR'  AS title, 'Jessica' AS first_name, 'Chastain' AS last_name, 2014 AS release_year
    UNION ALL
    SELECT 'JOKER' AS title, 'Joaquin' AS first_name, 'Phoenix' AS last_name, 2019 AS release_year
    UNION ALL
    SELECT 'JOKER' AS title, 'Robert' AS first_name, 'De Niro' AS last_name, 2019 AS release_year
    UNION ALL
    SELECT 'JOKER' AS title, 'Zazie' AS first_name, 'Beetz' AS last_name, 2019 AS release_year
),
new_language AS 
(
INSERT INTO public.language (name)
SELECT DISTINCT fd.language_name
FROM film_data fd
WHERE NOT EXISTS (SELECT * FROM public."language" l WHERE lower(l.name) = lower(fd.language_name))
RETURNING *
),
new_film AS
(
INSERT INTO public.film (title, release_year, language_id, rental_rate, rental_duration)
SELECT fd.title, fd.release_year, COALESCE (l.language_id, nl.language_id), fd.rental_rate, fd.rental_duration
FROM film_data fd
LEFT JOIN public."language" l ON lower(l.name) = lower(fd.language_name)
LEFT JOIN new_language nl ON lower(nl.name) = lower(fd.language_name)
WHERE NOT EXISTS (SELECT * FROM public.film f WHERE lower (f.title) = lower (fd.title) AND f.release_year = fd.RELEASE_year)
RETURNING *
),
new_actor AS 
(
INSERT INTO public.actor (first_name, last_name)
SELECT ad.first_name, ad.last_name
FROM actor_data ad
WHERE NOT EXISTS (SELECT * FROM public.actor a WHERE lower (a.first_name) = lower (ad.first_name) AND lower (a.last_name) = lower (ad.last_name))
RETURNING *
),
new_film_actor AS 
(
INSERT INTO public.film_actor (actor_id, film_id)
SELECT COALESCE (a.actor_id, na.actor_id),COALESCE (f.film_id, nf.film_id) 
FROM actor_data ad
LEFT JOIN public.film f ON lower (f.title) = lower (ad.title) AND f.release_year = ad.RELEASE_year
LEFT JOIN public.actor a ON lower (a.first_name) = lower (ad.first_name) AND lower (a.last_name) = lower (ad.last_name)
LEFT JOIN new_actor na ON (na.first_name) = lower (ad.first_name) AND lower (na.last_name) = lower (ad.last_name)
LEFT JOIN new_film nf ON lower (nf.title) = lower (ad.title) AND nf.release_year = ad.RELEASE_year
WHERE NOT EXISTS (SELECT * FROM public.film_actor fa WHERE a.actor_id = fa.actor_id AND f.film_id = fa.film_id)
RETURNING *
),
staff_store AS 
(
SELECT store_id, staff_id FROM public.staff LIMIT 1
),
new_inventory AS
(
INSERT INTO public.inventory (film_id, store_id)
SELECT nf.film_id, s.store_id
FROM new_film nf, staff_store s
RETURNING *
),
customer_for_update AS
(
SELECT t.customer_id, t.rental, t.payment_records
FROM
  (SELECT payment.customer_id, COUNT (DISTINCT rental_id) AS rental, COUNT (DISTINCT payment_id) AS payment_records
   FROM public.payment
   GROUP BY payment.customer_id
   ORDER by rental, payment_records)t
WHERE t.rental >= 43 AND t.payment_records >= 43
ORDER BY rental DESC
LIMIT 1
),
customer_update AS 
(
UPDATE public.customer
SET 
first_name = 'Andrei',
last_name = 'Aksionau', 
email = 'andrzej.aksionau@gmail.com',
address_id = (SELECT a.address_id FROM public.address a WHERE a.address_id <> customer.address_id LIMIT 1),
create_date = current_timestamp
WHERE customer_id IN (SELECT customer_id FROM customer_for_update)
RETURNING *
),
remove_payment AS
(
DELETE FROM public.payment 
WHERE customer_id IN (SELECT customer_id FROM customer_for_update)
RETURNING *
),
remove_rental AS
(
DELETE FROM  public.rental
WHERE customer_id IN (SELECT customer_id FROM customer_for_update)
RETURNING *
),
new_rental AS
(
INSERT INTO public.rental (rental_date, inventory_id, customer_id, staff_id)
SELECT current_timestamp, ni.inventory_id, cfu.customer_id, s.staff_id
FROM new_inventory ni, customer_for_update cfu, staff_store s
RETURNING *
)
INSERT INTO public.payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT cfu.customer_id, s.staff_id, nr.rental_id, 9.99, '2017-05-03'
FROM new_rental nr, staff_store s, customer_for_update cfu
RETURNING *

