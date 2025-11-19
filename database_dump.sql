--
-- PostgreSQL database dump
--

-- Dumped from database version 17.0
-- Dumped by pg_dump version 17.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: check_visit_overlap(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_visit_overlap() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверка пересечения по времени:
    -- Интервал считается как [visit_date, visit_date + 30 min)

    IF EXISTS (
        SELECT 1
        FROM visits v
        WHERE v.worker_id = NEW.worker_id
          AND v.visit_id <> COALESCE(NEW.visit_id, -1)
          AND tstzrange(v.visit_date,
                        v.visit_date + INTERVAL '30 minutes',
                        '[)')
              && 
              tstzrange(NEW.visit_date,
                        NEW.visit_date + INTERVAL '30 minutes',
                        '[)')
    ) THEN
        RAISE EXCEPTION 'Врач уже занят в это время. Минимальный интервал между записями — 30 минут.';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_visit_overlap() OWNER TO postgres;

--
-- Name: generate_medical_tests(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_medical_tests() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    visit_rec RECORD;
    num_tests INTEGER;
    test_name_val VARCHAR(100);
    test_code_val VARCHAR(20);
    test_date_val TIMESTAMPTZ;
    result_date_val TIMESTAMPTZ;
    results_val JSONB;
    normal_range_val JSONB;
    i INTEGER;
    test_names TEXT[] := ARRAY[
        'Complete Blood Count',
        'Blood Glucose Test',
        'Urinalysis',
        'ECG',
        'Liver Function Tests',
        'Thyroid Panel',
        'Lipid Profile',
        'X-Ray Chest',
        'Ultrasound Abdomen',
        'COVID-19 PCR',
        'Allergy Test',
        'Vitamin D Test',
        'Coagulation Panel',
        'MRI Spine',
        'CT Head',
        'Spirometry',
        'Renal Function Test',
        'Cardiac Enzymes',
        'HbA1c Test',
        'Stool Analysis'
    ];
BEGIN
    TRUNCATE TABLE medical_tests RESTART IDENTITY;

    FOR visit_rec IN SELECT visit_id, visit_date FROM visits ORDER BY visit_id LOOP
        -- Случайное количество анализов на визит (0-3)
        num_tests := floor(random() * 4)::INTEGER;
        
        FOR i IN 1..num_tests LOOP  -- ИСПРАВЛЕНО: 1..num_tests вместо 1 TO num_tests
            -- Случайный тип анализа
            test_name_val := test_names[floor(random() * array_length(test_names, 1) + 1)::INTEGER];
            
            -- Код НМУ
            test_code_val := 'LAB' || lpad(floor(random() * 1000)::INTEGER::TEXT, 3, '0');
            
            -- Дата анализа (в день визита или на следующий день)
            test_date_val := visit_rec.visit_date + (floor(random() * 2)::INTEGER || ' days')::INTERVAL;
            
            -- Дата результата (1-7 дней после анализа)
            result_date_val := test_date_val + ((floor(random() * 7) + 1)::INTEGER || ' days')::INTERVAL;
            
            -- Генерация результатов и референсных значений
            CASE test_name_val
                WHEN 'Complete Blood Count' THEN
                    results_val := jsonb_build_object(
                        'wbc', round((random() * 15 + 4)::numeric, 1),
                        'rbc', round((random() * 2 + 4)::numeric, 1),
                        'hgb', round((random() * 50 + 110)::numeric, 1),
                        'plt', (random() * 200 + 150)::INTEGER
                    );
                    normal_range_val := jsonb_build_object(
                        'wbc', '4.0-11.0',
                        'rbc', '4.5-6.0',
                        'hgb', '120-160',
                        'plt', '150-450'
                    );
                    
                WHEN 'Blood Glucose Test' THEN
                    results_val := jsonb_build_object(
                        'glucose', round((random() * 5 + 4)::numeric, 1)
                    );
                    normal_range_val := jsonb_build_object(
                        'glucose', '3.9-6.1'
                    );
                    
                WHEN 'Urinalysis' THEN
                    results_val := jsonb_build_object(
                        'color', (ARRAY['yellow', 'straw', 'amber'])[floor(random() * 3 + 1)::INTEGER],
                        'protein', round((random() * 0.1)::numeric, 2),
                        'glucose', round((random() * 0.5)::numeric, 2),
                        'leukocytes', (random() * 5)::INTEGER
                    );
                    normal_range_val := jsonb_build_object(
                        'color', 'yellow',
                        'protein', '0-0.03',
                        'glucose', '0',
                        'leukocytes', '0-5'
                    );
                    
                WHEN 'ECG' THEN
                    results_val := jsonb_build_object(
                        'rhythm', (ARRAY['sinus', 'regular', 'irregular'])[floor(random() * 3 + 1)::INTEGER],
                        'rate', (random() * 40 + 60)::INTEGER,
                        'conclusion', 'normal'
                    );
                    normal_range_val := jsonb_build_object(
                        'rhythm', 'sinus',
                        'rate', '60-100'
                    );
                    
                WHEN 'Liver Function Tests' THEN
                    results_val := jsonb_build_object(
                        'alt', (random() * 40 + 10)::INTEGER,
                        'ast', (random() * 35 + 10)::INTEGER,
                        'alp', (random() * 90 + 40)::INTEGER
                    );
                    normal_range_val := jsonb_build_object(
                        'alt', '10-40',
                        'ast', '10-35',
                        'alp', '40-130'
                    );
                    
                WHEN 'Lipid Profile' THEN
                    results_val := jsonb_build_object(
                        'cholesterol', round((random() * 3 + 3)::numeric, 1),
                        'hdl', round((random() * 1 + 1)::numeric, 1),
                        'ldl', round((random() * 2 + 2)::numeric, 1)
                    );
                    normal_range_val := jsonb_build_object(
                        'cholesterol', '<5.2',
                        'hdl', '>1.0',
                        'ldl', '<3.0'
                    );
                    
                ELSE
                    results_val := jsonb_build_object('result', 'within normal limits');
                    normal_range_val := jsonb_build_object('reference', 'standard values');
            END CASE;
            
            -- Вставка данных
            INSERT INTO medical_tests (
                visit_id, test_name, test_code, test_date, result_date,
                results, normal_range
            ) VALUES (
                visit_rec.visit_id, test_name_val, test_code_val, test_date_val, result_date_val,
                results_val, normal_range_val
            );
        END LOOP;
    END LOOP;
END;
$$;


ALTER FUNCTION public.generate_medical_tests() OWNER TO postgres;

--
-- Name: generate_medical_workers(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_medical_workers(num_workers integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    i INTEGER;
    clinic_id_val INTEGER;
    specialization_id_val INTEGER;
    first_name_val VARCHAR(50);
    last_name_val VARCHAR(50);
    phone_val VARCHAR(20);
    email_val VARCHAR(100);
    experience_years_val INTEGER;
    salary_val NUMERIC(10,2);
    hire_date_val DATE;
    email_prefix_val VARCHAR(50);
    base_experience INTEGER;
    additional_experience INTEGER;
    min_hire_date DATE;
BEGIN
    -- Минимальная дата найма (чтобы опыт не был отрицательным)
    min_hire_date := CURRENT_DATE - INTERVAL '35 years';
    
    FOR i IN 1..num_workers LOOP
        -- Случайная поликлиника (1-3)
        clinic_id_val := floor(random() * 3) + 1;
        
        -- Случайная специализация (1-10)
        specialization_id_val := floor(random() * 10) + 1;
        
        -- Случайное имя
        first_name_val := (ARRAY[
            'John','Michael','David','Robert','James','William','Richard','Thomas','Christopher','Daniel',
            'Emma','Olivia','Sophia','Ava','Isabella','Mia','Charlotte','Amelia','Harper','Evelyn'
        ])[floor(random() * 20) + 1];
        
        -- Случайная фамилия
        last_name_val := (ARRAY[
            'Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez',
            'Hernandez','Lopez','Gonzalez','Wilson','Anderson','Thomas','Taylor','Moore','Jackson','Martin'
        ])[floor(random() * 20) + 1];
        
        -- Случайный телефон
        phone_val := '+7' || lpad(floor(random() * 10000000000)::TEXT, 10, '0');
        
        -- Генерация email
        email_prefix_val := lower(
            (ARRAY[
                'alpha','beta','gamma','delta','epsilon','zeta','eta','theta','iota','kappa',
                'lambda','mu','nu','xi','omicron','pi','rho','sigma','tau','upsilon',
                'phi','chi','psi','omega','medical','health','care','clinic','hospital','doctor',
                'surgeon','therapy','wellness','vital','med','bio','life','aid','cure','heal'
            ])[floor(random() * 40) + 1] ||
            (ARRAY[
                'base','point','system','net','line','hub','center','unit','group','team',
                'source','link','node','zone','field','scope','view','mark','spot','site'
            ])[floor(random() * 20) + 1]
        ) || floor(random() * 10000)::TEXT;
        
        email_val := email_prefix_val || '@medical.org';
        
        -- Дата найма (от 1 до 35 лет назад)
        hire_date_val := min_hire_date + (floor(random() * (CURRENT_DATE - min_hire_date)) || ' days')::INTERVAL;
        
        -- Базовый опыт = разница в годах между текущей датой и датой найма
        base_experience := EXTRACT(YEAR FROM AGE(CURRENT_DATE, hire_date_val))::INTEGER;
        
        -- Дополнительный случайный опыт (от 0 до 10 лет)
        additional_experience := floor(random() * 11);
        
        -- Общий опыт работы
        experience_years_val := base_experience + additional_experience;
        
        -- Зарплата (от 50,000 до 350,000) на основе опыта
        salary_val := GREATEST(50000, LEAST(350000, 
            (50000 + (experience_years_val * 4000) + 
            (sqrt(-2.0 * ln(random())) * cos(2.0 * pi() * random()) * 25000))::numeric(10,2)
        ));
        
        -- Вставка данных
        INSERT INTO medical_workers (
            clinic_id, 
            specialization_id, 
            first_name, 
            last_name, 
            phone, 
            email, 
            experience_years, 
            salary, 
            hire_date
        ) VALUES (
            clinic_id_val,
            specialization_id_val,
            first_name_val,
            last_name_val,
            phone_val,
            email_val,
            experience_years_val,
            salary_val,
            hire_date_val
        );
        
    END LOOP;
END;
$$;


ALTER FUNCTION public.generate_medical_workers(num_workers integer) OWNER TO postgres;

--
-- Name: generate_prescriptions(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_prescriptions() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    visit_rec RECORD;
    num_prescriptions INTEGER;
    medication_name_val VARCHAR(100);
    duration_days_val INTEGER;
    start_date_val DATE;
    dose_val INTEGER; -- Количество приемов в день
    i INTEGER;
    medications TEXT[] := ARRAY[
        'Amoxicillin 500mg',
        'Ibuprofen 400mg',
        'Paracetamol 500mg',
        'Lisinopril 10mg',
        'Atorvastatin 20mg',
        'Metformin 500mg',
        'Vitamin D3 2000IU',
        'Amoxicillin 875mg',
        'Omeprazole 20mg',
        'Cetirizine 10mg',
        'Salbutamol Inhaler',
        'Calcium 600mg',
        'Warfarin 5mg',
        'Diazepam 5mg',
        'Amoxicillin 250mg',
        'Ibuprofen 200mg',
        'Levothyroxine 50mcg',
        'Amlodipine 5mg',
        'Metoprolol 25mg',
        'Aspirin 100mg'
    ];
BEGIN
    TRUNCATE TABLE prescriptions RESTART IDENTITY;

    FOR visit_rec IN SELECT visit_id, visit_date FROM visits ORDER BY visit_id LOOP
        -- Случайное количество назначений на визит (0-4)
        num_prescriptions := floor(random() * 5)::INTEGER;
        
        FOR i IN 1..num_prescriptions LOOP
            -- Случайное лекарство
            medication_name_val := medications[floor(random() * array_length(medications, 1) + 1)::INTEGER];
            
            -- Длительность приема (3-30 дней)
            duration_days_val := floor(random() * 28)::INTEGER + 3;
            
            -- Дата начала (в день визита)
            start_date_val := visit_rec.visit_date::DATE;
            
            -- Количество приемов в день (1-3 раза)
            dose_val := floor(random() * 3)::INTEGER + 1;
            
            -- Вставка данных (игнорируем дубликаты)
            BEGIN
                INSERT INTO prescriptions (
                    visit_id, medication_name, duration_days, start_date, dose
                ) VALUES (
                    visit_rec.visit_id, medication_name_val, duration_days_val, start_date_val, dose_val
                );
            EXCEPTION
                WHEN unique_violation THEN
                    -- Если такое лекарство уже назначено на этот визит
                    CONTINUE;
            END;
        END LOOP;
    END LOOP;
END;
$$;


ALTER FUNCTION public.generate_prescriptions() OWNER TO postgres;

--
-- Name: generate_random_patients(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_random_patients(n integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    i INTEGER;
    first_name_val VARCHAR(50);
    last_name_val VARCHAR(50);
    birth_date_val DATE;
    gender_val VARCHAR(1);
    phone_val VARCHAR(20);
    email_val VARCHAR(100);
    passport_series_val VARCHAR(4);
    passport_number_val VARCHAR(6);
    snils_val VARCHAR(14);
    address_val TEXT;
    street_number INTEGER;
    street_name_val VARCHAR(50);
    city_val VARCHAR(50);
BEGIN
    FOR i IN 1..n LOOP
        -- Генерация случайного имени
        first_name_val := (ARRAY['James','John','Robert','Michael','William','David','Richard','Joseph','Thomas','Charles',
                               'Mary','Patricia','Jennifer','Linda','Elizabeth','Barbara','Susan','Jessica','Sarah','Karen'])[floor(random() * 20 + 1)];
        
        -- Генерация случайной фамилии
        last_name_val := (ARRAY['Smith','Johnson','Williams','Brown','Jones','Miller','Davis','Garcia','Rodriguez','Wilson',
                              'Martinez','Anderson','Taylor','Thomas','Hernandez','Moore','Martin','Jackson','Thompson','White'])[floor(random() * 20 + 1)];
        
        -- Генерация случайной даты рождения (от 18 до 90 лет)
        birth_date_val := CURRENT_DATE - (floor(random() * (90*365 - 18*365) + 18*365) || ' days')::INTERVAL;
        
        -- Случайный пол
        gender_val := (ARRAY['M','F'])[floor(random() * 2 + 1)];
        
        -- Генерация российского номера телефона
        phone_val := '+7' || lpad(floor(random() * 10000000000)::TEXT, 10, '0');
        
        -- Генерация email
        email_val := lower(first_name_val) || '.' || lower(last_name_val) || floor(random() * 1000)::TEXT || 
                    (ARRAY['@gmail.com','@yahoo.com','@hotmail.com','@outlook.com'])[floor(random() * 4 + 1)];
        
        -- Генерация серии паспорта
        passport_series_val := lpad(floor(random() * 10000)::TEXT, 4, '0');
        
        -- Генерация номера паспорта
        passport_number_val := lpad(floor(random() * 1000000)::TEXT, 6, '0');
        
        -- Генерация СНИЛС
        snils_val := lpad(floor(random() * 1000)::TEXT, 3, '0') || '-' || 
                    lpad(floor(random() * 1000)::TEXT, 3, '0') || '-' || 
                    lpad(floor(random() * 1000)::TEXT, 3, '0') || ' ' || 
                    lpad(floor(random() * 100)::TEXT, 2, '0');
        
        street_number := floor(random() * 199) + 1; -- Номер дома от 1 до 199
        street_name_val := (ARRAY['Main St', 'Oak Ave', 'Pine Rd', 'Elm St', 'Maple Dr', 'Cedar Ln', 'Birch St', 'Spruce Way', 'Willow Rd', 'Aspen St'])[floor(random() * 10 + 1)];
        city_val := (ARRAY['Moscow', 'Saint Petersburg', 'Novosibirsk', 'Yekaterinburg', 'Kazan', 'Nizhny Novgorod', 'Chelyabinsk', 'Samara', 'Omsk', 'Rostov-on-Don'])[floor(random() * 10 + 1)];
        
        address_val := street_number::TEXT || ' ' || street_name_val || ', ' || city_val || ', Russia';
        -- Вставка данных
        INSERT INTO patients (
            first_name, last_name, birth_date, gender, phone, email, 
            passport_series, passport_number, snils, address
        ) VALUES (
            first_name_val, last_name_val, birth_date_val, gender_val, phone_val, email_val,
            passport_series_val, passport_number_val, snils_val, address_val
        );
        
    END LOOP;
END;
$$;


ALTER FUNCTION public.generate_random_patients(n integer) OWNER TO postgres;

--
-- Name: generate_random_visits(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_random_visits(num_visits integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    i INTEGER;
    patient_id_val INTEGER;
    worker_id_val INTEGER;
    visit_date_val TIMESTAMPTZ;
    visit_type_val VARCHAR(20);
    symptoms_val TEXT;
    temperature_val DECIMAL(3,1);
    bp_systolic_val INTEGER;
    bp_diastolic_val INTEGER;
    heart_rate_val INTEGER;
    random_days INTEGER;
    random_hours INTEGER;
BEGIN
    FOR i IN 1..num_visits LOOP
        -- Случайный пациент (от 1 до 120)
        patient_id_val := floor(random() * 120) + 1;
        
        -- Случайный мед работник (от 1 до 64)
        worker_id_val := floor(random() * 64) + 1;
        
        -- Случайная дата визита (от 1 года назад до текущего момента)
        random_days := floor(random() * 365);
        random_hours := floor(random() * 24);
        visit_date_val := CURRENT_TIMESTAMP - (random_days || ' days')::INTERVAL - (random_hours || ' hours')::INTERVAL + (floor(random() * 59) || ' minutes')::INTERVAL;
        
        -- Случайный тип визита
        visit_type_val := (ARRAY['examination', 'consultation', 'treatment', 'tests', 'surgery'])[floor(random() * 5 + 1)];
        
        -- Случайные симптомы (80% записей имеют симптомы)
        IF random() > 0.2 THEN
            symptoms_val := (ARRAY[
                'Headache, fever, and general fatigue',
                'Cough, sore throat, runny nose',
                'Chest pain and shortness of breath',
                'Abdominal pain, nausea, vomiting',
                'Back pain and muscle stiffness',
                'Dizziness and weakness',
                'Joint pain and swelling',
                'Skin rash and itching',
                'High blood pressure symptoms',
                'Allergic reaction',
                'Respiratory infection symptoms',
                'Gastrointestinal issues',
                'Neurological symptoms',
                'Cardiac symptoms',
                'Routine checkup - no symptoms'
            ])[floor(random() * 15 + 1)];
        ELSE
            symptoms_val := NULL;
        END IF;
        
        -- Случайная температура (35.5 - 37.5 для здоровых, 37.6 - 39.0 для больных)
        IF random() > 0.7 THEN
            temperature_val := 37.6 + (random() * 1.4); -- Повышенная температура
        ELSE
            temperature_val := 35.5 + (random() * 2.0); -- Нормальная температура
        END IF;
        
        -- Случайное артериальное давление
        bp_systolic_val := 100 + floor(random() * 60); -- 100-160
        bp_diastolic_val := 60 + floor(random() * 30); -- 60-90
        
        -- Гарантируем, что систолическое > диастолическое
        WHILE bp_systolic_val <= bp_diastolic_val LOOP
            bp_systolic_val := bp_systolic_val + 10;
        END LOOP;
        
        -- Случайный пульс
        heart_rate_val := 60 + floor(random() * 60); -- 60-120
        
        -- Вставка данных
        INSERT INTO visits (
            patient_id, worker_id, visit_date, visit_type,
            symptoms, temperature, blood_pressure_systolic, 
            blood_pressure_diastolic, heart_rate
        ) VALUES (
            patient_id_val, worker_id_val, visit_date_val, visit_type_val,
            symptoms_val, temperature_val, bp_systolic_val, 
            bp_diastolic_val, heart_rate_val
        );
        
    END LOOP;
END;
$$;


ALTER FUNCTION public.generate_random_visits(num_visits integer) OWNER TO postgres;

--
-- Name: generate_visit_diagnoses(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_visit_diagnoses() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    visit_rec RECORD;
    num_diagnoses INTEGER;
    diagnosis_id_val INTEGER;
    certainty_val VARCHAR(20);
    i INTEGER;
BEGIN
    -- Очищаем таблицу перед генерацией
    TRUNCATE TABLE visit_diagnoses;

    -- Для каждого визита добавляем случайное количество диагнозов
    FOR visit_rec IN SELECT visit_id FROM visits ORDER BY visit_id LOOP
        -- Случайное количество диагнозов на визит (1-3)
        num_diagnoses := floor(random() * 3) + 1;
        
        FOR i IN 1..num_diagnoses LOOP
            -- Случайный диагноз из 45 доступных
            diagnosis_id_val := floor(random() * 45) + 1;
            
            -- Случайный уровень уверенности
            certainty_val := (ARRAY['suspected', 'preliminary', 'confirmed'])[floor(random() * 3) + 1];
            
            -- Пытаемся вставить диагноз, игнорируем дубликаты (один диагноз на визит)
            BEGIN
                INSERT INTO visit_diagnoses (visit_id, diagnosis_id, certainty_level)
                VALUES (visit_rec.visit_id, diagnosis_id_val, certainty_val);
            EXCEPTION
                WHEN unique_violation THEN
                    -- Если такой диагноз уже есть для этого визита, пропускаем
                    CONTINUE;
            END;
        END LOOP;
    END LOOP;
END;
$$;


ALTER FUNCTION public.generate_visit_diagnoses() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: clinics; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.clinics (
    clinic_id integer NOT NULL,
    name character varying(100) NOT NULL,
    address character varying(200) NOT NULL,
    phone character varying(20),
    email character varying(100),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT clinics_email_check CHECK (((email)::text ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text)),
    CONSTRAINT clinics_phone_check CHECK (((phone)::text ~ '^\+7\d{10}$'::text))
);


ALTER TABLE public.clinics OWNER TO postgres;

--
-- Name: clinics_clinic_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.clinics_clinic_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.clinics_clinic_id_seq OWNER TO postgres;

--
-- Name: clinics_clinic_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.clinics_clinic_id_seq OWNED BY public.clinics.clinic_id;


--
-- Name: diagnoses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.diagnoses (
    diagnosis_id integer NOT NULL,
    icd_code character varying(10) NOT NULL
);


ALTER TABLE public.diagnoses OWNER TO postgres;

--
-- Name: diagnoses_diagnosis_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.diagnoses_diagnosis_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.diagnoses_diagnosis_id_seq OWNER TO postgres;

--
-- Name: diagnoses_diagnosis_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.diagnoses_diagnosis_id_seq OWNED BY public.diagnoses.diagnosis_id;


--
-- Name: medical_tests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.medical_tests (
    test_id integer NOT NULL,
    visit_id integer,
    test_name character varying(100) NOT NULL,
    test_code character varying(20),
    test_date timestamp with time zone NOT NULL,
    result_date timestamp with time zone,
    results jsonb,
    normal_range jsonb,
    CONSTRAINT medical_tests_check CHECK ((result_date >= test_date)),
    CONSTRAINT valid_test_date CHECK ((test_date <= CURRENT_TIMESTAMP))
);


ALTER TABLE public.medical_tests OWNER TO postgres;

--
-- Name: medical_tests_test_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.medical_tests_test_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.medical_tests_test_id_seq OWNER TO postgres;

--
-- Name: medical_tests_test_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.medical_tests_test_id_seq OWNED BY public.medical_tests.test_id;


--
-- Name: medical_workers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.medical_workers (
    worker_id integer NOT NULL,
    clinic_id integer,
    specialization_id integer,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    phone character varying(20),
    email character varying(100),
    experience_years integer,
    salary numeric(10,2),
    hire_date date,
    CONSTRAINT medical_workers_experience_years_check CHECK (((experience_years >= 0) AND (experience_years <= 60))),
    CONSTRAINT medical_workers_hire_date_check CHECK ((hire_date <= CURRENT_DATE)),
    CONSTRAINT medical_workers_phone_check CHECK (((phone)::text ~ '^\+7\d{10}$'::text)),
    CONSTRAINT medical_workers_salary_check CHECK (((salary >= (0)::numeric) OR (salary < (4000000)::numeric))),
    CONSTRAINT valid_email CHECK (((email IS NULL) OR ((email)::text ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text)))
);


ALTER TABLE public.medical_workers OWNER TO postgres;

--
-- Name: medical_workers_worker_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.medical_workers_worker_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.medical_workers_worker_id_seq OWNER TO postgres;

--
-- Name: medical_workers_worker_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.medical_workers_worker_id_seq OWNED BY public.medical_workers.worker_id;


--
-- Name: patients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.patients (
    patient_id integer NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    birth_date date,
    gender character varying(1),
    phone character varying(20),
    email character varying(100),
    passport_series character varying(4),
    passport_number character varying(6),
    snils character varying(14),
    address text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT patients_birth_date_check CHECK (((birth_date >= '1900-01-01'::date) AND (birth_date <= CURRENT_DATE))),
    CONSTRAINT patients_gender_check CHECK (((gender)::text = ANY ((ARRAY['M'::character varying, 'F'::character varying])::text[]))),
    CONSTRAINT patients_passport_number_check CHECK (((passport_number)::text ~ '^\d{6}$'::text)),
    CONSTRAINT patients_passport_series_check CHECK (((passport_series)::text ~ '^\d{4}$'::text)),
    CONSTRAINT patients_phone_check CHECK (((phone)::text ~ '^\+7\d{10}$'::text)),
    CONSTRAINT patients_snils_check CHECK (((snils)::text ~ '^\d{3}-\d{3}-\d{3} \d{2}$'::text)),
    CONSTRAINT valid_birth_date CHECK ((EXTRACT(year FROM age((birth_date)::timestamp with time zone)) <= (120)::numeric)),
    CONSTRAINT valid_email CHECK (((email IS NULL) OR ((email)::text ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text)))
);


ALTER TABLE public.patients OWNER TO postgres;

--
-- Name: patients_patient_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.patients_patient_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.patients_patient_id_seq OWNER TO postgres;

--
-- Name: patients_patient_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.patients_patient_id_seq OWNED BY public.patients.patient_id;


--
-- Name: prescriptions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.prescriptions (
    prescription_id integer NOT NULL,
    visit_id integer,
    medication_name character varying(100) NOT NULL,
    duration_days integer,
    start_date date DEFAULT CURRENT_DATE,
    dose integer,
    CONSTRAINT prescriptions_dose_check CHECK ((dose > 0)),
    CONSTRAINT prescriptions_duration_days_check CHECK (((duration_days >= 1) AND (duration_days <= 365)))
);


ALTER TABLE public.prescriptions OWNER TO postgres;

--
-- Name: prescriptions_prescription_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.prescriptions_prescription_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.prescriptions_prescription_id_seq OWNER TO postgres;

--
-- Name: prescriptions_prescription_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.prescriptions_prescription_id_seq OWNED BY public.prescriptions.prescription_id;


--
-- Name: specializations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.specializations (
    specialization_id integer NOT NULL,
    name character varying(50) NOT NULL,
    category character varying(30),
    CONSTRAINT specializations_category_check CHECK (((category)::text = ANY ((ARRAY['therapy'::character varying, 'surgery'::character varying, 'diagnostics'::character varying, 'pediatrics'::character varying])::text[])))
);


ALTER TABLE public.specializations OWNER TO postgres;

--
-- Name: specializations_specialization_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.specializations_specialization_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.specializations_specialization_id_seq OWNER TO postgres;

--
-- Name: specializations_specialization_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.specializations_specialization_id_seq OWNED BY public.specializations.specialization_id;


--
-- Name: visit_diagnoses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.visit_diagnoses (
    visit_id integer NOT NULL,
    diagnosis_id integer NOT NULL,
    certainty_level character varying(20),
    CONSTRAINT visit_diagnoses_certainty_level_check CHECK (((certainty_level)::text = ANY ((ARRAY['suspected'::character varying, 'preliminary'::character varying, 'confirmed'::character varying])::text[])))
);


ALTER TABLE public.visit_diagnoses OWNER TO postgres;

--
-- Name: visits; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.visits (
    visit_id integer NOT NULL,
    patient_id integer,
    worker_id integer,
    visit_date timestamp with time zone NOT NULL,
    visit_type character varying(20),
    symptoms text,
    temperature numeric(3,1),
    blood_pressure_systolic integer,
    blood_pressure_diastolic integer,
    heart_rate integer,
    CONSTRAINT valid_blood_pressure CHECK ((blood_pressure_systolic > blood_pressure_diastolic)),
    CONSTRAINT valid_visit_date CHECK ((visit_date <= (CURRENT_TIMESTAMP + '01:00:00'::interval))),
    CONSTRAINT visits_blood_pressure_diastolic_check CHECK (((blood_pressure_diastolic >= 40) AND (blood_pressure_diastolic <= 150))),
    CONSTRAINT visits_blood_pressure_systolic_check CHECK (((blood_pressure_systolic >= 60) AND (blood_pressure_systolic <= 250))),
    CONSTRAINT visits_heart_rate_check CHECK (((heart_rate >= 30) AND (heart_rate <= 200))),
    CONSTRAINT visits_temperature_check CHECK (((temperature >= (25)::numeric) AND (temperature <= (42)::numeric))),
    CONSTRAINT visits_visit_type_check CHECK (((visit_type)::text = ANY ((ARRAY['examination'::character varying, 'consultation'::character varying, 'treatment'::character varying, 'tests'::character varying, 'surgery'::character varying])::text[])))
);


ALTER TABLE public.visits OWNER TO postgres;

--
-- Name: visits_visit_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.visits_visit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.visits_visit_id_seq OWNER TO postgres;

--
-- Name: visits_visit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.visits_visit_id_seq OWNED BY public.visits.visit_id;


--
-- Name: clinics clinic_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clinics ALTER COLUMN clinic_id SET DEFAULT nextval('public.clinics_clinic_id_seq'::regclass);


--
-- Name: diagnoses diagnosis_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.diagnoses ALTER COLUMN diagnosis_id SET DEFAULT nextval('public.diagnoses_diagnosis_id_seq'::regclass);


--
-- Name: medical_tests test_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medical_tests ALTER COLUMN test_id SET DEFAULT nextval('public.medical_tests_test_id_seq'::regclass);


--
-- Name: medical_workers worker_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medical_workers ALTER COLUMN worker_id SET DEFAULT nextval('public.medical_workers_worker_id_seq'::regclass);


--
-- Name: patients patient_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients ALTER COLUMN patient_id SET DEFAULT nextval('public.patients_patient_id_seq'::regclass);


--
-- Name: prescriptions prescription_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescriptions ALTER COLUMN prescription_id SET DEFAULT nextval('public.prescriptions_prescription_id_seq'::regclass);


--
-- Name: specializations specialization_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.specializations ALTER COLUMN specialization_id SET DEFAULT nextval('public.specializations_specialization_id_seq'::regclass);


--
-- Name: visits visit_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visits ALTER COLUMN visit_id SET DEFAULT nextval('public.visits_visit_id_seq'::regclass);


--
-- Data for Name: clinics; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.clinics (clinic_id, name, address, phone, email, created_at) FROM stdin;
1	Central City Hospital	123 Main St, Moscow	+79151234567	central@hospital.ru	2025-11-17 17:25:22.390897+03
2	North Medical Center	456 Lenina Ave, Moscow	+79157654321	north@medical.ru	2025-11-17 17:25:22.390897+03
3	South Health Clinic	789 Gagarina St, Moscow	+79159876543	south@health.ru	2025-11-17 17:25:22.390897+03
\.


--
-- Data for Name: diagnoses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.diagnoses (diagnosis_id, icd_code) FROM stdin;
1	A01.0
2	A02.0
3	A15.0
4	A36.0
5	A37.0
6	C16.9
7	C18.9
8	C34.9
9	C50.9
10	C61
11	D50.0
12	D64.9
13	D69.3
14	E10.9
15	E11.9
16	E04.9
17	E05.9
18	F20.0
19	F32.9
20	F41.0
21	F43.2
22	G20
23	G40.9
24	G43.9
25	G35
26	I10
27	I20.9
28	I21.9
29	I48
30	I63.9
31	J06.9
32	J18.9
33	J45.9
34	J44.9
35	K21.9
36	K29.9
37	K35.9
38	K57.9
39	M15.9
40	M17.9
41	M54.9
42	S06.9
43	S22.9
44	S52.9
45	S83.9
\.


--
-- Data for Name: medical_tests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.medical_tests (test_id, visit_id, test_name, test_code, test_date, result_date, results, normal_range) FROM stdin;
1	3	Ultrasound Abdomen	LAB534	2025-09-28 16:26:01.158497+03	2025-10-03 16:26:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
2	3	Urinalysis	LAB866	2025-09-28 16:26:01.158497+03	2025-10-05 16:26:01.158497+03	{"color": "amber", "glucose": 0.40, "protein": 0.07, "leukocytes": 5}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
3	3	Urinalysis	LAB906	2025-09-27 16:26:01.158497+03	2025-09-30 16:26:01.158497+03	{"color": "straw", "glucose": 0.42, "protein": 0.04, "leukocytes": 2}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
4	4	HbA1c Test	LAB968	2025-03-19 05:20:01.158497+03	2025-03-20 05:20:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
5	4	Liver Function Tests	LAB691	2025-03-19 05:20:01.158497+03	2025-03-20 05:20:01.158497+03	{"alp": 73, "alt": 44, "ast": 28}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
6	5	CT Head	LAB025	2025-08-20 20:29:01.158497+03	2025-08-21 20:29:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
7	7	Complete Blood Count	LAB270	2025-03-08 19:31:01.158497+03	2025-03-13 19:31:01.158497+03	{"hgb": 126.7, "plt": 292, "rbc": 5.8, "wbc": 17.7}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
8	8	Thyroid Panel	LAB488	2025-07-03 18:58:01.158497+03	2025-07-06 18:58:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
9	8	COVID-19 PCR	LAB709	2025-07-02 18:58:01.158497+03	2025-07-05 18:58:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
10	8	Complete Blood Count	LAB070	2025-07-03 18:58:01.158497+03	2025-07-08 18:58:01.158497+03	{"hgb": 121.7, "plt": 302, "rbc": 5.7, "wbc": 11.4}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
11	10	X-Ray Chest	LAB167	2025-02-10 11:28:01.158497+03	2025-02-12 11:28:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
12	10	Allergy Test	LAB588	2025-02-11 11:28:01.158497+03	2025-02-13 11:28:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
13	12	Coagulation Panel	LAB655	2025-01-11 21:41:01.158497+03	2025-01-18 21:41:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
14	12	Coagulation Panel	LAB878	2025-01-10 21:41:01.158497+03	2025-01-14 21:41:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
15	14	Allergy Test	LAB871	2025-11-06 05:31:01.158497+03	2025-11-10 05:31:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
16	15	Urinalysis	LAB189	2025-08-20 02:00:01.158497+03	2025-08-23 02:00:01.158497+03	{"color": "straw", "glucose": 0.44, "protein": 0.08, "leukocytes": 5}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
17	16	COVID-19 PCR	LAB505	2025-06-05 17:05:01.158497+03	2025-06-10 17:05:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
18	16	Vitamin D Test	LAB697	2025-06-04 17:05:01.158497+03	2025-06-06 17:05:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
19	16	HbA1c Test	LAB152	2025-06-04 17:05:01.158497+03	2025-06-10 17:05:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
20	18	Stool Analysis	LAB738	2025-10-03 08:31:01.158497+03	2025-10-08 08:31:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
21	18	Lipid Profile	LAB966	2025-10-02 08:31:01.158497+03	2025-10-04 08:31:01.158497+03	{"hdl": 1.2, "ldl": 3.3, "cholesterol": 3.7}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
22	18	Ultrasound Abdomen	LAB725	2025-10-03 08:31:01.158497+03	2025-10-10 08:31:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
23	19	X-Ray Chest	LAB665	2025-08-06 11:18:01.158497+03	2025-08-12 11:18:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
24	21	Cardiac Enzymes	LAB272	2024-12-02 12:31:01.158497+03	2024-12-09 12:31:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
25	23	Renal Function Test	LAB342	2025-02-05 01:55:01.158497+03	2025-02-10 01:55:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
26	23	Stool Analysis	LAB753	2025-02-05 01:55:01.158497+03	2025-02-07 01:55:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
27	26	CT Head	LAB849	2025-03-09 03:24:01.158497+03	2025-03-11 03:24:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
28	26	Stool Analysis	LAB506	2025-03-09 03:24:01.158497+03	2025-03-12 03:24:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
29	27	Cardiac Enzymes	LAB477	2025-06-03 02:58:01.158497+03	2025-06-07 02:58:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
30	28	ECG	LAB437	2025-09-05 14:22:01.158497+03	2025-09-09 14:22:01.158497+03	{"rate": 98, "rhythm": "regular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
31	28	Liver Function Tests	LAB408	2025-09-06 14:22:01.158497+03	2025-09-12 14:22:01.158497+03	{"alp": 85, "alt": 31, "ast": 37}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
32	28	Renal Function Test	LAB646	2025-09-06 14:22:01.158497+03	2025-09-10 14:22:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
33	29	Complete Blood Count	LAB845	2025-05-19 20:36:01.158497+03	2025-05-24 20:36:01.158497+03	{"hgb": 112.4, "plt": 160, "rbc": 5.6, "wbc": 8.1}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
34	29	Renal Function Test	LAB107	2025-05-18 20:36:01.158497+03	2025-05-23 20:36:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
35	29	X-Ray Chest	LAB022	2025-05-18 20:36:01.158497+03	2025-05-21 20:36:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
36	31	CT Head	LAB417	2024-12-07 15:46:01.158497+03	2024-12-08 15:46:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
37	31	Liver Function Tests	LAB529	2024-12-07 15:46:01.158497+03	2024-12-10 15:46:01.158497+03	{"alp": 51, "alt": 29, "ast": 16}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
38	31	CT Head	LAB380	2024-12-07 15:46:01.158497+03	2024-12-13 15:46:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
39	32	MRI Spine	LAB189	2025-11-02 12:02:01.158497+03	2025-11-05 12:02:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
40	32	Renal Function Test	LAB968	2025-11-02 12:02:01.158497+03	2025-11-07 12:02:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
41	33	Vitamin D Test	LAB917	2025-07-15 17:33:01.158497+03	2025-07-17 17:33:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
42	33	Stool Analysis	LAB171	2025-07-15 17:33:01.158497+03	2025-07-20 17:33:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
43	34	Renal Function Test	LAB795	2024-11-29 22:44:01.158497+03	2024-12-01 22:44:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
44	35	Thyroid Panel	LAB596	2025-04-09 12:03:01.158497+03	2025-04-14 12:03:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
45	36	CT Head	LAB598	2025-06-21 11:23:01.158497+03	2025-06-26 11:23:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
46	37	Spirometry	LAB694	2025-06-18 10:03:01.158497+03	2025-06-22 10:03:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
47	39	Cardiac Enzymes	LAB301	2025-05-07 22:42:01.158497+03	2025-05-14 22:42:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
48	39	Stool Analysis	LAB793	2025-05-07 22:42:01.158497+03	2025-05-08 22:42:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
49	40	Allergy Test	LAB462	2025-04-02 16:58:01.158497+03	2025-04-03 16:58:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
50	40	Renal Function Test	LAB536	2025-04-01 16:58:01.158497+03	2025-04-07 16:58:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
51	41	ECG	LAB909	2025-04-16 17:09:01.158497+03	2025-04-22 17:09:01.158497+03	{"rate": 72, "rhythm": "sinus", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
52	42	Lipid Profile	LAB223	2025-08-19 02:33:01.158497+03	2025-08-26 02:33:01.158497+03	{"hdl": 1.0, "ldl": 2.2, "cholesterol": 5.8}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
53	43	Lipid Profile	LAB698	2025-08-11 04:33:01.158497+03	2025-08-18 04:33:01.158497+03	{"hdl": 1.2, "ldl": 3.4, "cholesterol": 4.7}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
54	43	Spirometry	LAB250	2025-08-11 04:33:01.158497+03	2025-08-15 04:33:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
55	43	Urinalysis	LAB911	2025-08-11 04:33:01.158497+03	2025-08-17 04:33:01.158497+03	{"color": "amber", "glucose": 0.41, "protein": 0.01, "leukocytes": 1}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
56	44	Cardiac Enzymes	LAB006	2025-03-27 06:37:01.158497+03	2025-04-03 06:37:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
57	44	CT Head	LAB066	2025-03-26 06:37:01.158497+03	2025-03-27 06:37:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
58	45	Stool Analysis	LAB819	2025-04-30 23:38:01.158497+03	2025-05-03 23:38:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
59	47	Renal Function Test	LAB742	2025-05-20 11:01:01.158497+03	2025-05-21 11:01:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
60	47	MRI Spine	LAB331	2025-05-20 11:01:01.158497+03	2025-05-21 11:01:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
61	47	Thyroid Panel	LAB630	2025-05-20 11:01:01.158497+03	2025-05-23 11:01:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
62	48	Lipid Profile	LAB907	2025-05-15 20:35:01.158497+03	2025-05-19 20:35:01.158497+03	{"hdl": 1.2, "ldl": 3.8, "cholesterol": 4.6}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
63	48	ECG	LAB333	2025-05-15 20:35:01.158497+03	2025-05-22 20:35:01.158497+03	{"rate": 95, "rhythm": "regular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
64	48	Cardiac Enzymes	LAB779	2025-05-15 20:35:01.158497+03	2025-05-16 20:35:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
65	50	Stool Analysis	LAB190	2025-05-19 15:30:01.158497+03	2025-05-21 15:30:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
66	51	X-Ray Chest	LAB245	2024-12-24 11:36:01.158497+03	2024-12-28 11:36:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
67	51	Renal Function Test	LAB783	2024-12-23 11:36:01.158497+03	2024-12-26 11:36:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
68	53	Allergy Test	LAB056	2025-05-19 23:12:01.158497+03	2025-05-20 23:12:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
69	54	MRI Spine	LAB043	2025-07-21 19:12:01.158497+03	2025-07-24 19:12:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
70	58	Stool Analysis	LAB753	2025-01-17 23:52:01.158497+03	2025-01-19 23:52:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
71	59	Ultrasound Abdomen	LAB590	2025-05-15 02:55:01.158497+03	2025-05-17 02:55:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
72	59	Cardiac Enzymes	LAB743	2025-05-15 02:55:01.158497+03	2025-05-18 02:55:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
73	61	Liver Function Tests	LAB097	2025-10-31 03:56:01.158497+03	2025-11-07 03:56:01.158497+03	{"alp": 101, "alt": 35, "ast": 15}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
74	61	Thyroid Panel	LAB403	2025-10-30 03:56:01.158497+03	2025-10-31 03:56:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
75	63	Ultrasound Abdomen	LAB991	2024-12-03 09:17:01.158497+03	2024-12-09 09:17:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
76	63	Lipid Profile	LAB536	2024-12-04 09:17:01.158497+03	2024-12-08 09:17:01.158497+03	{"hdl": 1.9, "ldl": 3.4, "cholesterol": 4.5}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
77	63	Complete Blood Count	LAB083	2024-12-04 09:17:01.158497+03	2024-12-07 09:17:01.158497+03	{"hgb": 148.0, "plt": 231, "rbc": 4.8, "wbc": 8.5}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
78	64	ECG	LAB960	2025-06-11 17:04:01.158497+03	2025-06-18 17:04:01.158497+03	{"rate": 87, "rhythm": "irregular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
79	64	Complete Blood Count	LAB375	2025-06-10 17:04:01.158497+03	2025-06-13 17:04:01.158497+03	{"hgb": 110.6, "plt": 298, "rbc": 4.0, "wbc": 11.4}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
80	64	Allergy Test	LAB320	2025-06-10 17:04:01.158497+03	2025-06-13 17:04:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
81	65	ECG	LAB124	2024-12-21 01:37:01.158497+03	2024-12-28 01:37:01.158497+03	{"rate": 81, "rhythm": "irregular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
82	66	Liver Function Tests	LAB066	2025-06-25 04:36:01.158497+03	2025-07-02 04:36:01.158497+03	{"alp": 118, "alt": 42, "ast": 15}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
83	68	Vitamin D Test	LAB149	2025-09-18 22:15:01.158497+03	2025-09-25 22:15:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
84	69	ECG	LAB529	2025-01-14 00:41:01.158497+03	2025-01-15 00:41:01.158497+03	{"rate": 75, "rhythm": "irregular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
85	70	Urinalysis	LAB272	2025-05-23 11:53:01.158497+03	2025-05-28 11:53:01.158497+03	{"color": "amber", "glucose": 0.40, "protein": 0.06, "leukocytes": 5}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
86	72	Cardiac Enzymes	LAB856	2025-03-18 20:30:01.158497+03	2025-03-25 20:30:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
87	72	Coagulation Panel	LAB571	2025-03-17 20:30:01.158497+03	2025-03-24 20:30:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
132	94	MRI Spine	LAB061	2025-08-12 10:51:01.158497+03	2025-08-13 10:51:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
88	72	Complete Blood Count	LAB438	2025-03-18 20:30:01.158497+03	2025-03-22 20:30:01.158497+03	{"hgb": 151.3, "plt": 242, "rbc": 5.3, "wbc": 9.8}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
89	74	Renal Function Test	LAB188	2025-06-17 13:23:01.158497+03	2025-06-20 13:23:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
90	74	MRI Spine	LAB934	2025-06-17 13:23:01.158497+03	2025-06-20 13:23:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
91	74	Vitamin D Test	LAB546	2025-06-17 13:23:01.158497+03	2025-06-20 13:23:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
92	75	Vitamin D Test	LAB948	2025-11-06 17:55:01.158497+03	2025-11-07 17:55:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
93	75	HbA1c Test	LAB522	2025-11-06 17:55:01.158497+03	2025-11-09 17:55:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
94	75	COVID-19 PCR	LAB314	2025-11-07 17:55:01.158497+03	2025-11-13 17:55:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
95	76	Cardiac Enzymes	LAB841	2025-03-16 17:51:01.158497+03	2025-03-21 17:51:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
96	76	Urinalysis	LAB552	2025-03-16 17:51:01.158497+03	2025-03-22 17:51:01.158497+03	{"color": "straw", "glucose": 0.35, "protein": 0.05, "leukocytes": 1}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
97	78	Vitamin D Test	LAB689	2025-02-01 07:57:01.158497+03	2025-02-03 07:57:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
98	78	Complete Blood Count	LAB735	2025-02-01 07:57:01.158497+03	2025-02-05 07:57:01.158497+03	{"hgb": 135.8, "plt": 195, "rbc": 4.8, "wbc": 10.8}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
99	80	Spirometry	LAB697	2025-08-18 14:06:01.158497+03	2025-08-19 14:06:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
100	80	Complete Blood Count	LAB997	2025-08-18 14:06:01.158497+03	2025-08-24 14:06:01.158497+03	{"hgb": 134.9, "plt": 255, "rbc": 5.8, "wbc": 16.9}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
101	82	Thyroid Panel	LAB135	2025-02-16 12:21:01.158497+03	2025-02-21 12:21:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
102	82	Vitamin D Test	LAB627	2025-02-16 12:21:01.158497+03	2025-02-17 12:21:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
103	83	Thyroid Panel	LAB669	2025-01-22 15:44:01.158497+03	2025-01-25 15:44:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
104	83	Allergy Test	LAB303	2025-01-22 15:44:01.158497+03	2025-01-26 15:44:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
105	83	HbA1c Test	LAB646	2025-01-23 15:44:01.158497+03	2025-01-28 15:44:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
106	84	Blood Glucose Test	LAB807	2025-02-15 05:28:01.158497+03	2025-02-20 05:28:01.158497+03	{"glucose": 7.2}	{"glucose": "3.9-6.1"}
107	84	Ultrasound Abdomen	LAB470	2025-02-16 05:28:01.158497+03	2025-02-17 05:28:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
108	85	Vitamin D Test	LAB742	2025-02-15 09:48:01.158497+03	2025-02-16 09:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
109	85	Spirometry	LAB327	2025-02-14 09:48:01.158497+03	2025-02-19 09:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
110	85	HbA1c Test	LAB817	2025-02-15 09:48:01.158497+03	2025-02-17 09:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
111	86	Urinalysis	LAB604	2025-01-09 15:48:01.158497+03	2025-01-12 15:48:01.158497+03	{"color": "straw", "glucose": 0.36, "protein": 0.01, "leukocytes": 1}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
112	86	COVID-19 PCR	LAB775	2025-01-08 15:48:01.158497+03	2025-01-10 15:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
113	86	CT Head	LAB820	2025-01-09 15:48:01.158497+03	2025-01-11 15:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
114	87	Complete Blood Count	LAB207	2025-01-22 04:48:01.158497+03	2025-01-27 04:48:01.158497+03	{"hgb": 130.6, "plt": 278, "rbc": 6.0, "wbc": 8.0}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
115	87	Allergy Test	LAB296	2025-01-22 04:48:01.158497+03	2025-01-28 04:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
116	87	COVID-19 PCR	LAB633	2025-01-21 04:48:01.158497+03	2025-01-27 04:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
117	88	Ultrasound Abdomen	LAB383	2025-05-17 06:15:01.158497+03	2025-05-19 06:15:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
118	88	Allergy Test	LAB816	2025-05-18 06:15:01.158497+03	2025-05-19 06:15:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
119	89	Cardiac Enzymes	LAB023	2025-08-11 09:58:01.158497+03	2025-08-14 09:58:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
120	89	MRI Spine	LAB306	2025-08-11 09:58:01.158497+03	2025-08-17 09:58:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
121	89	Thyroid Panel	LAB340	2025-08-12 09:58:01.158497+03	2025-08-16 09:58:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
122	90	Thyroid Panel	LAB025	2025-09-02 20:23:01.158497+03	2025-09-05 20:23:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
123	90	Liver Function Tests	LAB478	2025-09-02 20:23:01.158497+03	2025-09-08 20:23:01.158497+03	{"alp": 61, "alt": 28, "ast": 13}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
124	91	Vitamin D Test	LAB354	2025-04-28 09:55:01.158497+03	2025-04-29 09:55:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
125	91	Stool Analysis	LAB732	2025-04-29 09:55:01.158497+03	2025-05-04 09:55:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
126	91	CT Head	LAB300	2025-04-29 09:55:01.158497+03	2025-05-02 09:55:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
127	92	Liver Function Tests	LAB950	2025-03-10 19:28:01.158497+03	2025-03-16 19:28:01.158497+03	{"alp": 97, "alt": 48, "ast": 12}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
128	92	Cardiac Enzymes	LAB667	2025-03-10 19:28:01.158497+03	2025-03-15 19:28:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
129	92	Thyroid Panel	LAB252	2025-03-10 19:28:01.158497+03	2025-03-12 19:28:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
130	93	Complete Blood Count	LAB658	2025-03-26 02:59:01.158497+03	2025-04-02 02:59:01.158497+03	{"hgb": 157.2, "plt": 347, "rbc": 5.6, "wbc": 9.3}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
131	94	Vitamin D Test	LAB964	2025-08-12 10:51:01.158497+03	2025-08-18 10:51:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
133	94	Stool Analysis	LAB185	2025-08-13 10:51:01.158497+03	2025-08-15 10:51:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
134	95	MRI Spine	LAB846	2025-09-14 21:13:01.158497+03	2025-09-18 21:13:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
135	96	X-Ray Chest	LAB379	2025-10-12 12:39:01.158497+03	2025-10-15 12:39:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
136	96	Vitamin D Test	LAB945	2025-10-11 12:39:01.158497+03	2025-10-12 12:39:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
137	97	Renal Function Test	LAB122	2025-02-11 06:48:01.158497+03	2025-02-14 06:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
138	98	Liver Function Tests	LAB866	2024-12-23 01:32:01.158497+03	2024-12-28 01:32:01.158497+03	{"alp": 94, "alt": 30, "ast": 20}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
139	98	Thyroid Panel	LAB588	2024-12-24 01:32:01.158497+03	2024-12-26 01:32:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
140	98	Renal Function Test	LAB612	2024-12-23 01:32:01.158497+03	2024-12-29 01:32:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
141	101	COVID-19 PCR	LAB394	2025-09-13 15:09:01.158497+03	2025-09-18 15:09:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
142	101	Ultrasound Abdomen	LAB830	2025-09-12 15:09:01.158497+03	2025-09-17 15:09:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
143	102	CT Head	LAB022	2025-01-23 05:20:01.158497+03	2025-01-29 05:20:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
144	102	Thyroid Panel	LAB081	2025-01-24 05:20:01.158497+03	2025-01-31 05:20:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
145	102	Spirometry	LAB584	2025-01-23 05:20:01.158497+03	2025-01-26 05:20:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
146	103	Blood Glucose Test	LAB070	2025-03-02 18:23:01.158497+03	2025-03-05 18:23:01.158497+03	{"glucose": 8.8}	{"glucose": "3.9-6.1"}
147	104	Allergy Test	LAB259	2024-11-30 20:10:01.158497+03	2024-12-02 20:10:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
148	104	Stool Analysis	LAB599	2024-12-01 20:10:01.158497+03	2024-12-05 20:10:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
149	106	Renal Function Test	LAB459	2025-08-09 16:24:01.158497+03	2025-08-12 16:24:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
150	106	CT Head	LAB843	2025-08-09 16:24:01.158497+03	2025-08-16 16:24:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
151	106	HbA1c Test	LAB840	2025-08-08 16:24:01.158497+03	2025-08-15 16:24:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
152	107	Complete Blood Count	LAB747	2025-01-07 13:21:01.158497+03	2025-01-09 13:21:01.158497+03	{"hgb": 130.4, "plt": 292, "rbc": 4.4, "wbc": 12.0}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
153	107	Urinalysis	LAB350	2025-01-07 13:21:01.158497+03	2025-01-09 13:21:01.158497+03	{"color": "yellow", "glucose": 0.25, "protein": 0.03, "leukocytes": 3}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
154	107	COVID-19 PCR	LAB563	2025-01-08 13:21:01.158497+03	2025-01-14 13:21:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
155	108	Vitamin D Test	LAB280	2025-08-27 03:58:01.158497+03	2025-08-31 03:58:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
156	109	Allergy Test	LAB829	2025-05-10 22:42:01.158497+03	2025-05-15 22:42:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
157	109	Thyroid Panel	LAB207	2025-05-10 22:42:01.158497+03	2025-05-16 22:42:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
158	109	CT Head	LAB365	2025-05-10 22:42:01.158497+03	2025-05-12 22:42:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
159	110	Coagulation Panel	LAB770	2025-01-04 22:14:01.158497+03	2025-01-11 22:14:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
160	111	Lipid Profile	LAB514	2025-09-04 03:23:01.158497+03	2025-09-09 03:23:01.158497+03	{"hdl": 1.5, "ldl": 2.4, "cholesterol": 3.3}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
161	111	Cardiac Enzymes	LAB407	2025-09-04 03:23:01.158497+03	2025-09-10 03:23:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
162	111	COVID-19 PCR	LAB750	2025-09-04 03:23:01.158497+03	2025-09-10 03:23:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
163	113	Blood Glucose Test	LAB949	2025-06-11 00:10:01.158497+03	2025-06-18 00:10:01.158497+03	{"glucose": 4.5}	{"glucose": "3.9-6.1"}
164	113	HbA1c Test	LAB796	2025-06-11 00:10:01.158497+03	2025-06-13 00:10:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
165	114	Spirometry	LAB190	2024-11-21 00:51:01.158497+03	2024-11-25 00:51:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
166	114	Coagulation Panel	LAB223	2024-11-22 00:51:01.158497+03	2024-11-29 00:51:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
167	116	Renal Function Test	LAB790	2025-03-03 16:43:01.158497+03	2025-03-04 16:43:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
168	116	CT Head	LAB630	2025-03-03 16:43:01.158497+03	2025-03-06 16:43:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
169	117	ECG	LAB204	2025-05-08 05:41:01.158497+03	2025-05-14 05:41:01.158497+03	{"rate": 62, "rhythm": "irregular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
170	117	Coagulation Panel	LAB257	2025-05-08 05:41:01.158497+03	2025-05-11 05:41:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
171	118	Complete Blood Count	LAB368	2025-04-11 21:53:01.158497+03	2025-04-13 21:53:01.158497+03	{"hgb": 131.4, "plt": 268, "rbc": 4.7, "wbc": 6.9}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
172	118	ECG	LAB770	2025-04-10 21:53:01.158497+03	2025-04-11 21:53:01.158497+03	{"rate": 69, "rhythm": "irregular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
173	119	Coagulation Panel	LAB436	2025-07-29 16:38:01.158497+03	2025-08-02 16:38:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
174	119	HbA1c Test	LAB900	2025-07-29 16:38:01.158497+03	2025-07-31 16:38:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
175	119	X-Ray Chest	LAB452	2025-07-30 16:38:01.158497+03	2025-08-01 16:38:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
176	122	Spirometry	LAB985	2025-07-09 11:56:01.158497+03	2025-07-12 11:56:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
177	122	X-Ray Chest	LAB511	2025-07-09 11:56:01.158497+03	2025-07-12 11:56:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
178	122	Liver Function Tests	LAB351	2025-07-08 11:56:01.158497+03	2025-07-10 11:56:01.158497+03	{"alp": 58, "alt": 32, "ast": 31}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
179	123	Thyroid Panel	LAB174	2025-07-23 18:30:01.158497+03	2025-07-24 18:30:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
180	124	MRI Spine	LAB235	2025-08-28 06:05:01.158497+03	2025-08-30 06:05:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
181	125	ECG	LAB075	2025-09-14 06:47:01.158497+03	2025-09-18 06:47:01.158497+03	{"rate": 61, "rhythm": "irregular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
182	125	Complete Blood Count	LAB230	2025-09-14 06:47:01.158497+03	2025-09-15 06:47:01.158497+03	{"hgb": 114.2, "plt": 158, "rbc": 5.2, "wbc": 15.5}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
183	125	Urinalysis	LAB659	2025-09-15 06:47:01.158497+03	2025-09-20 06:47:01.158497+03	{"color": "yellow", "glucose": 0.24, "protein": 0.06, "leukocytes": 4}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
184	126	Urinalysis	LAB760	2025-10-18 04:43:01.158497+03	2025-10-19 04:43:01.158497+03	{"color": "yellow", "glucose": 0.38, "protein": 0.09, "leukocytes": 4}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
185	126	Spirometry	LAB416	2025-10-19 04:43:01.158497+03	2025-10-24 04:43:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
186	127	Ultrasound Abdomen	LAB265	2025-07-28 18:10:01.158497+03	2025-08-01 18:10:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
187	127	Lipid Profile	LAB521	2025-07-29 18:10:01.158497+03	2025-08-04 18:10:01.158497+03	{"hdl": 1.9, "ldl": 2.7, "cholesterol": 3.6}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
188	129	Stool Analysis	LAB170	2025-09-16 11:32:01.158497+03	2025-09-18 11:32:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
189	129	HbA1c Test	LAB196	2025-09-15 11:32:01.158497+03	2025-09-20 11:32:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
190	129	ECG	LAB991	2025-09-16 11:32:01.158497+03	2025-09-23 11:32:01.158497+03	{"rate": 81, "rhythm": "sinus", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
191	131	Liver Function Tests	LAB754	2025-04-20 20:24:01.158497+03	2025-04-24 20:24:01.158497+03	{"alp": 55, "alt": 26, "ast": 41}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
192	132	ECG	LAB451	2025-06-30 05:09:01.158497+03	2025-07-06 05:09:01.158497+03	{"rate": 74, "rhythm": "regular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
193	132	Vitamin D Test	LAB277	2025-07-01 05:09:01.158497+03	2025-07-04 05:09:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
194	136	HbA1c Test	LAB810	2025-07-04 22:37:01.158497+03	2025-07-11 22:37:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
195	136	Lipid Profile	LAB800	2025-07-04 22:37:01.158497+03	2025-07-10 22:37:01.158497+03	{"hdl": 1.7, "ldl": 2.2, "cholesterol": 3.6}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
196	137	Allergy Test	LAB683	2024-11-29 13:59:01.158497+03	2024-12-02 13:59:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
197	137	Spirometry	LAB652	2024-11-29 13:59:01.158497+03	2024-12-05 13:59:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
198	138	Complete Blood Count	LAB861	2025-06-26 04:55:01.158497+03	2025-06-27 04:55:01.158497+03	{"hgb": 149.8, "plt": 167, "rbc": 5.3, "wbc": 11.7}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
199	140	Stool Analysis	LAB782	2025-07-31 09:39:01.158497+03	2025-08-02 09:39:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
200	140	Allergy Test	LAB542	2025-08-01 09:39:01.158497+03	2025-08-07 09:39:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
201	143	ECG	LAB763	2024-12-19 09:21:01.158497+03	2024-12-23 09:21:01.158497+03	{"rate": 99, "rhythm": "regular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
202	143	Spirometry	LAB537	2024-12-19 09:21:01.158497+03	2024-12-24 09:21:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
203	144	Renal Function Test	LAB210	2025-09-12 13:16:01.158497+03	2025-09-15 13:16:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
204	145	Ultrasound Abdomen	LAB904	2025-01-20 02:51:01.158497+03	2025-01-24 02:51:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
205	145	Cardiac Enzymes	LAB571	2025-01-20 02:51:01.158497+03	2025-01-21 02:51:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
206	146	CT Head	LAB570	2025-05-17 21:13:01.158497+03	2025-05-19 21:13:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
207	146	CT Head	LAB422	2025-05-17 21:13:01.158497+03	2025-05-24 21:13:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
208	148	Renal Function Test	LAB609	2025-01-09 16:04:01.158497+03	2025-01-12 16:04:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
209	148	Lipid Profile	LAB777	2025-01-10 16:04:01.158497+03	2025-01-17 16:04:01.158497+03	{"hdl": 1.0, "ldl": 3.4, "cholesterol": 5.0}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
210	150	Thyroid Panel	LAB824	2025-04-02 15:06:01.158497+03	2025-04-07 15:06:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
211	150	Vitamin D Test	LAB701	2025-04-03 15:06:01.158497+03	2025-04-07 15:06:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
212	150	Stool Analysis	LAB310	2025-04-02 15:06:01.158497+03	2025-04-03 15:06:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
213	151	Liver Function Tests	LAB333	2025-06-09 22:16:01.158497+03	2025-06-16 22:16:01.158497+03	{"alp": 127, "alt": 48, "ast": 11}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
214	151	ECG	LAB431	2025-06-08 22:16:01.158497+03	2025-06-10 22:16:01.158497+03	{"rate": 74, "rhythm": "sinus", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
215	151	HbA1c Test	LAB663	2025-06-09 22:16:01.158497+03	2025-06-11 22:16:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
216	152	HbA1c Test	LAB565	2024-12-03 17:45:01.158497+03	2024-12-10 17:45:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
217	152	Ultrasound Abdomen	LAB417	2024-12-04 17:45:01.158497+03	2024-12-10 17:45:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
218	153	Spirometry	LAB111	2025-02-08 14:48:01.158497+03	2025-02-09 14:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
219	153	CT Head	LAB317	2025-02-07 14:48:01.158497+03	2025-02-10 14:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
220	154	CT Head	LAB585	2024-12-07 14:40:01.158497+03	2024-12-14 14:40:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
221	154	Ultrasound Abdomen	LAB318	2024-12-07 14:40:01.158497+03	2024-12-14 14:40:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
222	154	Thyroid Panel	LAB406	2024-12-08 14:40:01.158497+03	2024-12-13 14:40:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
223	156	CT Head	LAB016	2025-08-04 00:03:01.158497+03	2025-08-07 00:03:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
224	156	Thyroid Panel	LAB905	2025-08-04 00:03:01.158497+03	2025-08-09 00:03:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
225	156	ECG	LAB582	2025-08-03 00:03:01.158497+03	2025-08-10 00:03:01.158497+03	{"rate": 99, "rhythm": "sinus", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
226	161	HbA1c Test	LAB058	2024-12-25 03:58:01.158497+03	2024-12-29 03:58:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
227	162	Ultrasound Abdomen	LAB204	2025-03-29 11:21:01.158497+03	2025-03-30 11:21:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
228	163	Ultrasound Abdomen	LAB377	2024-11-20 01:47:01.158497+03	2024-11-27 01:47:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
229	163	Urinalysis	LAB282	2024-11-19 01:47:01.158497+03	2024-11-21 01:47:01.158497+03	{"color": "amber", "glucose": 0.04, "protein": 0.08, "leukocytes": 3}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
230	164	Spirometry	LAB853	2025-09-18 19:29:01.158497+03	2025-09-19 19:29:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
231	164	Ultrasound Abdomen	LAB473	2025-09-19 19:29:01.158497+03	2025-09-24 19:29:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
232	164	HbA1c Test	LAB471	2025-09-18 19:29:01.158497+03	2025-09-22 19:29:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
233	166	HbA1c Test	LAB548	2025-09-17 20:32:01.158497+03	2025-09-19 20:32:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
234	167	X-Ray Chest	LAB012	2025-02-16 21:08:01.158497+03	2025-02-20 21:08:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
235	167	Urinalysis	LAB178	2025-02-16 21:08:01.158497+03	2025-02-22 21:08:01.158497+03	{"color": "amber", "glucose": 0.09, "protein": 0.05, "leukocytes": 1}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
236	167	Complete Blood Count	LAB467	2025-02-17 21:08:01.158497+03	2025-02-18 21:08:01.158497+03	{"hgb": 151.7, "plt": 293, "rbc": 4.1, "wbc": 9.2}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
237	168	Spirometry	LAB543	2025-07-11 01:55:01.158497+03	2025-07-17 01:55:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
238	168	Complete Blood Count	LAB309	2025-07-11 01:55:01.158497+03	2025-07-14 01:55:01.158497+03	{"hgb": 126.2, "plt": 237, "rbc": 5.9, "wbc": 14.1}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
239	168	Urinalysis	LAB024	2025-07-12 01:55:01.158497+03	2025-07-13 01:55:01.158497+03	{"color": "amber", "glucose": 0.35, "protein": 0.07, "leukocytes": 0}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
240	170	MRI Spine	LAB228	2025-01-28 23:54:01.158497+03	2025-02-04 23:54:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
241	170	CT Head	LAB388	2025-01-28 23:54:01.158497+03	2025-01-29 23:54:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
242	170	Blood Glucose Test	LAB164	2025-01-28 23:54:01.158497+03	2025-02-03 23:54:01.158497+03	{"glucose": 8.2}	{"glucose": "3.9-6.1"}
243	173	Urinalysis	LAB634	2025-10-24 16:51:01.158497+03	2025-10-29 16:51:01.158497+03	{"color": "yellow", "glucose": 0.44, "protein": 0.03, "leukocytes": 4}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
244	173	Coagulation Panel	LAB829	2025-10-25 16:51:01.158497+03	2025-10-27 16:51:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
245	176	Spirometry	LAB629	2025-03-13 16:48:01.158497+03	2025-03-17 16:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
246	177	Blood Glucose Test	LAB887	2025-05-18 09:50:01.158497+03	2025-05-21 09:50:01.158497+03	{"glucose": 5.6}	{"glucose": "3.9-6.1"}
247	177	Coagulation Panel	LAB169	2025-05-17 09:50:01.158497+03	2025-05-23 09:50:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
248	178	Coagulation Panel	LAB424	2025-02-24 02:17:01.158497+03	2025-02-28 02:17:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
249	178	COVID-19 PCR	LAB536	2025-02-25 02:17:01.158497+03	2025-03-02 02:17:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
250	178	Renal Function Test	LAB459	2025-02-25 02:17:01.158497+03	2025-03-02 02:17:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
251	179	Ultrasound Abdomen	LAB790	2024-12-30 10:22:01.158497+03	2025-01-01 10:22:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
252	180	Complete Blood Count	LAB305	2025-02-20 12:24:01.158497+03	2025-02-26 12:24:01.158497+03	{"hgb": 116.7, "plt": 337, "rbc": 4.4, "wbc": 12.9}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
253	180	Allergy Test	LAB493	2025-02-21 12:24:01.158497+03	2025-02-22 12:24:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
254	180	COVID-19 PCR	LAB310	2025-02-21 12:24:01.158497+03	2025-02-27 12:24:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
255	182	Coagulation Panel	LAB687	2025-10-11 12:29:01.158497+03	2025-10-16 12:29:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
256	183	Stool Analysis	LAB898	2025-06-11 20:25:01.158497+03	2025-06-14 20:25:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
257	183	HbA1c Test	LAB991	2025-06-11 20:25:01.158497+03	2025-06-16 20:25:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
258	184	COVID-19 PCR	LAB018	2025-05-06 20:26:01.158497+03	2025-05-10 20:26:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
259	185	Renal Function Test	LAB197	2024-11-21 10:48:01.158497+03	2024-11-23 10:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
260	185	CT Head	LAB662	2024-11-21 10:48:01.158497+03	2024-11-24 10:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
261	185	COVID-19 PCR	LAB455	2024-11-21 10:48:01.158497+03	2024-11-28 10:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
262	186	ECG	LAB522	2025-01-08 19:01:01.158497+03	2025-01-09 19:01:01.158497+03	{"rate": 81, "rhythm": "regular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
263	186	Lipid Profile	LAB738	2025-01-09 19:01:01.158497+03	2025-01-12 19:01:01.158497+03	{"hdl": 1.7, "ldl": 2.0, "cholesterol": 5.6}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
264	187	Coagulation Panel	LAB981	2025-10-10 16:26:01.158497+03	2025-10-13 16:26:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
265	187	MRI Spine	LAB438	2025-10-09 16:26:01.158497+03	2025-10-12 16:26:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
266	187	Stool Analysis	LAB506	2025-10-10 16:26:01.158497+03	2025-10-12 16:26:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
267	188	Liver Function Tests	LAB203	2025-09-21 05:44:01.158497+03	2025-09-25 05:44:01.158497+03	{"alp": 45, "alt": 26, "ast": 22}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
268	189	X-Ray Chest	LAB802	2025-10-07 01:29:01.158497+03	2025-10-14 01:29:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
269	191	Spirometry	LAB137	2025-02-04 01:44:01.158497+03	2025-02-05 01:44:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
270	191	Thyroid Panel	LAB813	2025-02-03 01:44:01.158497+03	2025-02-08 01:44:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
271	192	ECG	LAB157	2025-10-10 13:45:01.158497+03	2025-10-13 13:45:01.158497+03	{"rate": 62, "rhythm": "irregular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
272	192	X-Ray Chest	LAB845	2025-10-09 13:45:01.158497+03	2025-10-14 13:45:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
273	192	Renal Function Test	LAB785	2025-10-10 13:45:01.158497+03	2025-10-16 13:45:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
274	193	Renal Function Test	LAB493	2025-03-09 20:51:01.158497+03	2025-03-11 20:51:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
275	193	X-Ray Chest	LAB750	2025-03-08 20:51:01.158497+03	2025-03-13 20:51:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
276	194	Complete Blood Count	LAB899	2025-04-26 06:04:01.158497+03	2025-04-28 06:04:01.158497+03	{"hgb": 156.4, "plt": 222, "rbc": 5.6, "wbc": 14.2}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
277	194	Stool Analysis	LAB522	2025-04-26 06:04:01.158497+03	2025-04-28 06:04:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
278	194	Blood Glucose Test	LAB544	2025-04-25 06:04:01.158497+03	2025-04-27 06:04:01.158497+03	{"glucose": 4.5}	{"glucose": "3.9-6.1"}
279	195	Cardiac Enzymes	LAB636	2025-02-23 23:05:01.158497+03	2025-02-24 23:05:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
280	196	Spirometry	LAB495	2025-01-17 11:15:01.158497+03	2025-01-22 11:15:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
281	197	Complete Blood Count	LAB308	2025-10-19 10:56:01.158497+03	2025-10-24 10:56:01.158497+03	{"hgb": 155.7, "plt": 276, "rbc": 5.6, "wbc": 4.5}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
282	201	Stool Analysis	LAB335	2025-11-03 04:10:01.158497+03	2025-11-09 04:10:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
283	201	COVID-19 PCR	LAB448	2025-11-03 04:10:01.158497+03	2025-11-07 04:10:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
284	201	Thyroid Panel	LAB290	2025-11-03 04:10:01.158497+03	2025-11-05 04:10:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
285	203	Ultrasound Abdomen	LAB131	2025-09-07 22:35:01.158497+03	2025-09-13 22:35:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
286	204	CT Head	LAB653	2025-06-13 06:38:01.158497+03	2025-06-16 06:38:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
287	204	Allergy Test	LAB784	2025-06-14 06:38:01.158497+03	2025-06-17 06:38:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
288	205	Complete Blood Count	LAB411	2025-02-07 15:52:01.158497+03	2025-02-12 15:52:01.158497+03	{"hgb": 160.0, "plt": 246, "rbc": 4.1, "wbc": 6.8}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
289	205	Vitamin D Test	LAB746	2025-02-06 15:52:01.158497+03	2025-02-11 15:52:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
290	205	COVID-19 PCR	LAB272	2025-02-06 15:52:01.158497+03	2025-02-11 15:52:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
291	207	CT Head	LAB101	2025-04-30 09:35:01.158497+03	2025-05-05 09:35:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
292	208	Cardiac Enzymes	LAB313	2025-10-31 15:25:01.158497+03	2025-11-06 15:25:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
293	208	Cardiac Enzymes	LAB474	2025-10-30 15:25:01.158497+03	2025-11-02 15:25:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
294	209	HbA1c Test	LAB618	2025-10-10 08:24:01.158497+03	2025-10-15 08:24:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
295	209	Vitamin D Test	LAB755	2025-10-10 08:24:01.158497+03	2025-10-15 08:24:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
296	210	Urinalysis	LAB474	2025-05-24 23:33:01.158497+03	2025-05-25 23:33:01.158497+03	{"color": "straw", "glucose": 0.16, "protein": 0.06, "leukocytes": 2}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
297	210	Cardiac Enzymes	LAB010	2025-05-25 23:33:01.158497+03	2025-05-30 23:33:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
298	210	MRI Spine	LAB622	2025-05-25 23:33:01.158497+03	2025-05-26 23:33:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
299	211	Complete Blood Count	LAB517	2025-07-14 09:17:01.158497+03	2025-07-16 09:17:01.158497+03	{"hgb": 114.9, "plt": 323, "rbc": 5.9, "wbc": 11.3}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
300	211	Stool Analysis	LAB243	2025-07-15 09:17:01.158497+03	2025-07-21 09:17:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
301	211	Complete Blood Count	LAB739	2025-07-14 09:17:01.158497+03	2025-07-21 09:17:01.158497+03	{"hgb": 121.2, "plt": 235, "rbc": 5.4, "wbc": 17.5}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
302	212	Lipid Profile	LAB851	2025-08-03 08:38:01.158497+03	2025-08-10 08:38:01.158497+03	{"hdl": 1.4, "ldl": 3.6, "cholesterol": 3.8}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
303	212	CT Head	LAB873	2025-08-02 08:38:01.158497+03	2025-08-07 08:38:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
304	213	Renal Function Test	LAB602	2025-08-23 21:32:01.158497+03	2025-08-30 21:32:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
305	213	Ultrasound Abdomen	LAB061	2025-08-24 21:32:01.158497+03	2025-08-26 21:32:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
306	213	Coagulation Panel	LAB312	2025-08-24 21:32:01.158497+03	2025-08-27 21:32:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
307	214	Complete Blood Count	LAB859	2025-01-12 06:26:01.158497+03	2025-01-18 06:26:01.158497+03	{"hgb": 150.8, "plt": 266, "rbc": 4.3, "wbc": 16.6}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
308	214	Urinalysis	LAB512	2025-01-12 06:26:01.158497+03	2025-01-15 06:26:01.158497+03	{"color": "yellow", "glucose": 0.24, "protein": 0.09, "leukocytes": 5}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
309	214	ECG	LAB288	2025-01-13 06:26:01.158497+03	2025-01-15 06:26:01.158497+03	{"rate": 99, "rhythm": "irregular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
310	215	HbA1c Test	LAB568	2025-10-08 05:50:01.158497+03	2025-10-15 05:50:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
311	215	ECG	LAB399	2025-10-08 05:50:01.158497+03	2025-10-13 05:50:01.158497+03	{"rate": 89, "rhythm": "sinus", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
312	215	Allergy Test	LAB528	2025-10-08 05:50:01.158497+03	2025-10-11 05:50:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
313	217	ECG	LAB495	2025-08-14 03:38:01.158497+03	2025-08-18 03:38:01.158497+03	{"rate": 61, "rhythm": "regular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
314	218	COVID-19 PCR	LAB535	2025-06-01 16:43:01.158497+03	2025-06-04 16:43:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
315	218	MRI Spine	LAB296	2025-06-01 16:43:01.158497+03	2025-06-07 16:43:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
316	220	Spirometry	LAB983	2025-06-17 11:49:01.158497+03	2025-06-23 11:49:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
317	220	Renal Function Test	LAB131	2025-06-16 11:49:01.158497+03	2025-06-17 11:49:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
318	220	CT Head	LAB848	2025-06-16 11:49:01.158497+03	2025-06-19 11:49:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
319	221	ECG	LAB736	2025-09-27 09:39:01.158497+03	2025-09-29 09:39:01.158497+03	{"rate": 69, "rhythm": "sinus", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
320	221	Urinalysis	LAB364	2025-09-26 09:39:01.158497+03	2025-10-01 09:39:01.158497+03	{"color": "yellow", "glucose": 0.29, "protein": 0.09, "leukocytes": 4}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
321	221	CT Head	LAB032	2025-09-26 09:39:01.158497+03	2025-09-27 09:39:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
322	222	Complete Blood Count	LAB815	2025-03-12 16:22:01.158497+03	2025-03-16 16:22:01.158497+03	{"hgb": 137.5, "plt": 259, "rbc": 4.9, "wbc": 16.2}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
323	222	Allergy Test	LAB147	2025-03-12 16:22:01.158497+03	2025-03-18 16:22:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
324	223	Coagulation Panel	LAB081	2025-03-19 20:42:01.158497+03	2025-03-22 20:42:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
325	224	Stool Analysis	LAB857	2025-06-13 02:32:01.158497+03	2025-06-19 02:32:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
326	224	Renal Function Test	LAB460	2025-06-13 02:32:01.158497+03	2025-06-19 02:32:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
327	225	Stool Analysis	LAB103	2025-01-07 06:27:01.158497+03	2025-01-10 06:27:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
328	226	Lipid Profile	LAB933	2025-11-03 08:14:01.158497+03	2025-11-05 08:14:01.158497+03	{"hdl": 1.6, "ldl": 3.1, "cholesterol": 5.5}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
329	226	Renal Function Test	LAB772	2025-11-03 08:14:01.158497+03	2025-11-10 08:14:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
330	228	Complete Blood Count	LAB610	2025-02-17 11:54:01.158497+03	2025-02-21 11:54:01.158497+03	{"hgb": 154.9, "plt": 341, "rbc": 5.3, "wbc": 15.4}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
331	228	Cardiac Enzymes	LAB423	2025-02-16 11:54:01.158497+03	2025-02-22 11:54:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
332	229	Allergy Test	LAB790	2025-11-15 09:28:01.158497+03	2025-11-17 09:28:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
333	229	Ultrasound Abdomen	LAB920	2025-11-15 09:28:01.158497+03	2025-11-22 09:28:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
334	229	Cardiac Enzymes	LAB125	2025-11-15 09:28:01.158497+03	2025-11-16 09:28:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
335	230	HbA1c Test	LAB376	2025-08-01 11:50:01.158497+03	2025-08-07 11:50:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
336	233	Ultrasound Abdomen	LAB442	2025-08-27 13:20:01.158497+03	2025-08-31 13:20:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
337	233	Cardiac Enzymes	LAB143	2025-08-27 13:20:01.158497+03	2025-09-01 13:20:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
338	234	Vitamin D Test	LAB691	2025-03-29 11:09:01.158497+03	2025-04-02 11:09:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
339	234	Urinalysis	LAB519	2025-03-30 11:09:01.158497+03	2025-04-04 11:09:01.158497+03	{"color": "straw", "glucose": 0.07, "protein": 0.09, "leukocytes": 4}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
340	234	Urinalysis	LAB854	2025-03-29 11:09:01.158497+03	2025-04-01 11:09:01.158497+03	{"color": "yellow", "glucose": 0.21, "protein": 0.04, "leukocytes": 2}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
341	236	Vitamin D Test	LAB570	2025-05-11 14:03:01.158497+03	2025-05-13 14:03:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
342	236	Lipid Profile	LAB976	2025-05-11 14:03:01.158497+03	2025-05-16 14:03:01.158497+03	{"hdl": 1.6, "ldl": 3.4, "cholesterol": 4.6}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
343	237	Ultrasound Abdomen	LAB281	2025-08-20 20:01:01.158497+03	2025-08-24 20:01:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
344	238	Vitamin D Test	LAB558	2025-07-29 01:30:01.158497+03	2025-08-04 01:30:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
345	239	Stool Analysis	LAB449	2024-11-22 16:52:01.158497+03	2024-11-26 16:52:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
346	240	Complete Blood Count	LAB934	2024-12-14 20:04:01.158497+03	2024-12-17 20:04:01.158497+03	{"hgb": 142.2, "plt": 177, "rbc": 4.4, "wbc": 12.1}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
347	240	Thyroid Panel	LAB969	2024-12-14 20:04:01.158497+03	2024-12-21 20:04:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
348	240	Renal Function Test	LAB662	2024-12-13 20:04:01.158497+03	2024-12-17 20:04:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
349	241	Spirometry	LAB403	2025-03-12 04:03:01.158497+03	2025-03-13 04:03:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
350	243	Renal Function Test	LAB737	2025-11-09 01:35:01.158497+03	2025-11-16 01:35:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
351	243	Coagulation Panel	LAB989	2025-11-09 01:35:01.158497+03	2025-11-16 01:35:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
352	244	Lipid Profile	LAB220	2025-06-11 19:37:01.158497+03	2025-06-12 19:37:01.158497+03	{"hdl": 1.6, "ldl": 3.8, "cholesterol": 3.2}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
353	245	Cardiac Enzymes	LAB932	2025-07-07 21:34:01.158497+03	2025-07-10 21:34:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
354	247	CT Head	LAB636	2025-04-26 13:48:01.158497+03	2025-05-03 13:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
355	248	Thyroid Panel	LAB996	2025-04-14 06:39:01.158497+03	2025-04-18 06:39:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
356	248	Cardiac Enzymes	LAB329	2025-04-13 06:39:01.158497+03	2025-04-20 06:39:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
357	248	Urinalysis	LAB030	2025-04-13 06:39:01.158497+03	2025-04-15 06:39:01.158497+03	{"color": "yellow", "glucose": 0.39, "protein": 0.05, "leukocytes": 5}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
358	249	Ultrasound Abdomen	LAB598	2025-02-05 07:56:01.158497+03	2025-02-08 07:56:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
359	249	CT Head	LAB616	2025-02-06 07:56:01.158497+03	2025-02-10 07:56:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
360	250	Vitamin D Test	LAB845	2025-06-12 08:39:01.158497+03	2025-06-13 08:39:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
361	250	Liver Function Tests	LAB506	2025-06-11 08:39:01.158497+03	2025-06-13 08:39:01.158497+03	{"alp": 71, "alt": 49, "ast": 29}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
362	250	Ultrasound Abdomen	LAB965	2025-06-11 08:39:01.158497+03	2025-06-17 08:39:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
363	251	Spirometry	LAB536	2024-12-03 16:49:01.158497+03	2024-12-10 16:49:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
364	251	Coagulation Panel	LAB547	2024-12-03 16:49:01.158497+03	2024-12-07 16:49:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
365	252	CT Head	LAB653	2025-06-08 22:19:01.158497+03	2025-06-09 22:19:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
366	252	Renal Function Test	LAB782	2025-06-09 22:19:01.158497+03	2025-06-16 22:19:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
367	253	Vitamin D Test	LAB573	2025-06-05 15:22:01.158497+03	2025-06-12 15:22:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
368	253	Vitamin D Test	LAB330	2025-06-05 15:22:01.158497+03	2025-06-11 15:22:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
369	254	Spirometry	LAB198	2025-01-14 10:14:01.158497+03	2025-01-20 10:14:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
370	256	Urinalysis	LAB999	2025-06-04 16:08:01.158497+03	2025-06-10 16:08:01.158497+03	{"color": "straw", "glucose": 0.09, "protein": 0.09, "leukocytes": 1}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
371	256	X-Ray Chest	LAB228	2025-06-05 16:08:01.158497+03	2025-06-07 16:08:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
372	256	ECG	LAB890	2025-06-04 16:08:01.158497+03	2025-06-05 16:08:01.158497+03	{"rate": 94, "rhythm": "irregular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
373	257	HbA1c Test	LAB789	2025-08-30 01:20:01.158497+03	2025-09-05 01:20:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
374	258	Vitamin D Test	LAB239	2025-03-22 17:43:01.158497+03	2025-03-26 17:43:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
375	259	CT Head	LAB613	2025-03-12 17:15:01.158497+03	2025-03-17 17:15:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
376	259	ECG	LAB068	2025-03-11 17:15:01.158497+03	2025-03-12 17:15:01.158497+03	{"rate": 67, "rhythm": "sinus", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
377	259	Thyroid Panel	LAB580	2025-03-11 17:15:01.158497+03	2025-03-14 17:15:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
378	260	Complete Blood Count	LAB971	2025-03-05 06:53:01.158497+03	2025-03-07 06:53:01.158497+03	{"hgb": 129.1, "plt": 201, "rbc": 6.0, "wbc": 16.1}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
379	260	Blood Glucose Test	LAB229	2025-03-05 06:53:01.158497+03	2025-03-11 06:53:01.158497+03	{"glucose": 7.9}	{"glucose": "3.9-6.1"}
380	260	Coagulation Panel	LAB597	2025-03-05 06:53:01.158497+03	2025-03-12 06:53:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
381	263	MRI Spine	LAB503	2025-06-16 08:56:01.158497+03	2025-06-22 08:56:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
382	263	Lipid Profile	LAB900	2025-06-16 08:56:01.158497+03	2025-06-22 08:56:01.158497+03	{"hdl": 1.5, "ldl": 3.0, "cholesterol": 3.6}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
383	264	Urinalysis	LAB849	2025-03-26 02:47:01.158497+03	2025-03-28 02:47:01.158497+03	{"color": "straw", "glucose": 0.28, "protein": 0.01, "leukocytes": 3}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
384	264	X-Ray Chest	LAB448	2025-03-25 02:47:01.158497+03	2025-03-30 02:47:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
385	264	COVID-19 PCR	LAB114	2025-03-26 02:47:01.158497+03	2025-03-27 02:47:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
386	265	Spirometry	LAB765	2025-01-25 19:54:01.158497+03	2025-01-26 19:54:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
387	265	Cardiac Enzymes	LAB869	2025-01-25 19:54:01.158497+03	2025-01-28 19:54:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
388	265	Cardiac Enzymes	LAB678	2025-01-24 19:54:01.158497+03	2025-01-25 19:54:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
389	266	Spirometry	LAB320	2025-11-10 10:16:01.158497+03	2025-11-16 10:16:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
390	266	Lipid Profile	LAB190	2025-11-10 10:16:01.158497+03	2025-11-13 10:16:01.158497+03	{"hdl": 1.7, "ldl": 3.9, "cholesterol": 5.9}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
391	268	Renal Function Test	LAB740	2024-12-05 13:14:01.158497+03	2024-12-11 13:14:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
392	268	Renal Function Test	LAB058	2024-12-05 13:14:01.158497+03	2024-12-07 13:14:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
393	269	Blood Glucose Test	LAB818	2024-11-30 09:26:01.158497+03	2024-12-06 09:26:01.158497+03	{"glucose": 6.7}	{"glucose": "3.9-6.1"}
394	269	X-Ray Chest	LAB005	2024-12-01 09:26:01.158497+03	2024-12-03 09:26:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
395	271	CT Head	LAB865	2025-08-22 19:52:01.158497+03	2025-08-24 19:52:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
396	272	Blood Glucose Test	LAB701	2025-08-18 11:43:01.158497+03	2025-08-21 11:43:01.158497+03	{"glucose": 7.1}	{"glucose": "3.9-6.1"}
397	273	Urinalysis	LAB486	2025-08-19 05:50:01.158497+03	2025-08-22 05:50:01.158497+03	{"color": "yellow", "glucose": 0.42, "protein": 0.06, "leukocytes": 3}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
398	274	Ultrasound Abdomen	LAB385	2025-10-16 00:44:01.158497+03	2025-10-19 00:44:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
399	275	Urinalysis	LAB553	2025-01-21 23:56:01.158497+03	2025-01-25 23:56:01.158497+03	{"color": "yellow", "glucose": 0.18, "protein": 0.03, "leukocytes": 2}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
400	275	X-Ray Chest	LAB671	2025-01-21 23:56:01.158497+03	2025-01-22 23:56:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
401	276	Allergy Test	LAB804	2025-09-13 03:29:01.158497+03	2025-09-17 03:29:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
402	277	Liver Function Tests	LAB994	2025-08-27 10:21:01.158497+03	2025-09-02 10:21:01.158497+03	{"alp": 75, "alt": 43, "ast": 32}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
403	278	Liver Function Tests	LAB801	2025-08-11 17:58:01.158497+03	2025-08-16 17:58:01.158497+03	{"alp": 72, "alt": 13, "ast": 32}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
404	278	Renal Function Test	LAB348	2025-08-12 17:58:01.158497+03	2025-08-19 17:58:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
405	279	Cardiac Enzymes	LAB494	2025-05-13 00:21:01.158497+03	2025-05-17 00:21:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
406	279	CT Head	LAB208	2025-05-12 00:21:01.158497+03	2025-05-13 00:21:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
407	280	ECG	LAB384	2025-08-14 04:30:01.158497+03	2025-08-20 04:30:01.158497+03	{"rate": 75, "rhythm": "irregular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
408	280	Lipid Profile	LAB756	2025-08-14 04:30:01.158497+03	2025-08-21 04:30:01.158497+03	{"hdl": 1.3, "ldl": 3.9, "cholesterol": 5.8}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
409	281	Spirometry	LAB261	2025-08-07 05:28:01.158497+03	2025-08-13 05:28:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
410	281	Renal Function Test	LAB917	2025-08-07 05:28:01.158497+03	2025-08-08 05:28:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
411	281	CT Head	LAB728	2025-08-07 05:28:01.158497+03	2025-08-12 05:28:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
412	283	CT Head	LAB780	2024-12-08 07:48:01.158497+03	2024-12-10 07:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
413	283	Thyroid Panel	LAB933	2024-12-08 07:48:01.158497+03	2024-12-13 07:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
414	284	Complete Blood Count	LAB286	2024-12-03 00:58:01.158497+03	2024-12-10 00:58:01.158497+03	{"hgb": 153.2, "plt": 151, "rbc": 4.5, "wbc": 5.1}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
415	284	Urinalysis	LAB444	2024-12-03 00:58:01.158497+03	2024-12-08 00:58:01.158497+03	{"color": "amber", "glucose": 0.28, "protein": 0.07, "leukocytes": 0}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
416	285	Allergy Test	LAB318	2025-05-29 16:38:01.158497+03	2025-05-30 16:38:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
417	285	Ultrasound Abdomen	LAB577	2025-05-29 16:38:01.158497+03	2025-05-31 16:38:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
418	285	CT Head	LAB555	2025-05-29 16:38:01.158497+03	2025-06-05 16:38:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
419	286	ECG	LAB914	2024-11-22 14:10:01.158497+03	2024-11-25 14:10:01.158497+03	{"rate": 66, "rhythm": "irregular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
420	287	Thyroid Panel	LAB863	2025-04-17 23:55:01.158497+03	2025-04-20 23:55:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
421	287	Spirometry	LAB382	2025-04-17 23:55:01.158497+03	2025-04-18 23:55:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
422	287	MRI Spine	LAB206	2025-04-16 23:55:01.158497+03	2025-04-18 23:55:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
423	288	Allergy Test	LAB136	2025-01-11 04:50:01.158497+03	2025-01-18 04:50:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
424	289	Ultrasound Abdomen	LAB621	2025-05-09 21:43:01.158497+03	2025-05-16 21:43:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
425	290	Cardiac Enzymes	LAB529	2025-01-25 01:34:01.158497+03	2025-01-27 01:34:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
426	290	Complete Blood Count	LAB931	2025-01-25 01:34:01.158497+03	2025-01-29 01:34:01.158497+03	{"hgb": 118.2, "plt": 339, "rbc": 4.3, "wbc": 18.5}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
427	290	Blood Glucose Test	LAB714	2025-01-25 01:34:01.158497+03	2025-01-31 01:34:01.158497+03	{"glucose": 7.5}	{"glucose": "3.9-6.1"}
428	291	Ultrasound Abdomen	LAB874	2025-10-15 22:23:01.158497+03	2025-10-19 22:23:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
429	291	HbA1c Test	LAB931	2025-10-15 22:23:01.158497+03	2025-10-21 22:23:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
430	291	Urinalysis	LAB259	2025-10-15 22:23:01.158497+03	2025-10-20 22:23:01.158497+03	{"color": "amber", "glucose": 0.42, "protein": 0.05, "leukocytes": 1}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
431	292	Ultrasound Abdomen	LAB963	2025-01-25 13:29:01.158497+03	2025-01-30 13:29:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
432	292	Stool Analysis	LAB717	2025-01-25 13:29:01.158497+03	2025-01-31 13:29:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
433	293	Complete Blood Count	LAB526	2025-03-02 01:56:01.158497+03	2025-03-04 01:56:01.158497+03	{"hgb": 118.3, "plt": 332, "rbc": 5.2, "wbc": 5.2}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
434	293	MRI Spine	LAB373	2025-03-02 01:56:01.158497+03	2025-03-09 01:56:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
435	293	Liver Function Tests	LAB241	2025-03-03 01:56:01.158497+03	2025-03-05 01:56:01.158497+03	{"alp": 84, "alt": 35, "ast": 40}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
436	294	CT Head	LAB579	2025-02-13 00:42:01.158497+03	2025-02-19 00:42:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
437	294	Coagulation Panel	LAB961	2025-02-14 00:42:01.158497+03	2025-02-18 00:42:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
438	294	CT Head	LAB292	2025-02-13 00:42:01.158497+03	2025-02-18 00:42:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
439	296	Complete Blood Count	LAB696	2025-07-15 05:48:01.158497+03	2025-07-18 05:48:01.158497+03	{"hgb": 150.8, "plt": 340, "rbc": 4.9, "wbc": 12.6}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
440	297	Thyroid Panel	LAB657	2025-08-29 12:02:01.158497+03	2025-08-31 12:02:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
441	297	Urinalysis	LAB589	2025-08-30 12:02:01.158497+03	2025-09-01 12:02:01.158497+03	{"color": "yellow", "glucose": 0.18, "protein": 0.08, "leukocytes": 3}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
442	298	Spirometry	LAB543	2025-06-22 03:43:01.158497+03	2025-06-24 03:43:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
443	299	Liver Function Tests	LAB855	2025-03-14 18:13:01.158497+03	2025-03-20 18:13:01.158497+03	{"alp": 109, "alt": 24, "ast": 36}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
444	299	ECG	LAB479	2025-03-13 18:13:01.158497+03	2025-03-20 18:13:01.158497+03	{"rate": 75, "rhythm": "sinus", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
445	300	Stool Analysis	LAB607	2025-02-14 01:34:01.158497+03	2025-02-19 01:34:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
446	301	Ultrasound Abdomen	LAB784	2025-06-27 03:15:01.158497+03	2025-07-04 03:15:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
447	303	Allergy Test	LAB917	2025-11-01 16:03:01.158497+03	2025-11-06 16:03:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
448	303	Stool Analysis	LAB966	2025-11-01 16:03:01.158497+03	2025-11-06 16:03:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
449	305	Blood Glucose Test	LAB910	2025-04-23 05:18:01.158497+03	2025-04-29 05:18:01.158497+03	{"glucose": 6.7}	{"glucose": "3.9-6.1"}
450	305	ECG	LAB748	2025-04-24 05:18:01.158497+03	2025-04-26 05:18:01.158497+03	{"rate": 69, "rhythm": "irregular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
451	307	Allergy Test	LAB209	2025-11-09 08:42:01.158497+03	2025-11-12 08:42:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
452	307	Urinalysis	LAB355	2025-11-09 08:42:01.158497+03	2025-11-14 08:42:01.158497+03	{"color": "straw", "glucose": 0.05, "protein": 0.07, "leukocytes": 0}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
453	307	Complete Blood Count	LAB216	2025-11-09 08:42:01.158497+03	2025-11-16 08:42:01.158497+03	{"hgb": 110.5, "plt": 279, "rbc": 4.5, "wbc": 4.4}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
454	308	Coagulation Panel	LAB848	2025-10-02 11:57:01.158497+03	2025-10-04 11:57:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
455	309	HbA1c Test	LAB831	2025-05-10 23:51:01.158497+03	2025-05-14 23:51:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
456	310	Spirometry	LAB045	2025-09-04 05:50:01.158497+03	2025-09-09 05:50:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
457	311	ECG	LAB954	2025-10-15 00:48:01.158497+03	2025-10-20 00:48:01.158497+03	{"rate": 92, "rhythm": "sinus", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
458	311	Liver Function Tests	LAB258	2025-10-16 00:48:01.158497+03	2025-10-21 00:48:01.158497+03	{"alp": 77, "alt": 28, "ast": 14}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
459	311	COVID-19 PCR	LAB425	2025-10-15 00:48:01.158497+03	2025-10-22 00:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
460	312	Spirometry	LAB914	2025-10-28 07:59:01.158497+03	2025-11-02 07:59:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
461	313	Liver Function Tests	LAB224	2024-12-07 23:15:01.158497+03	2024-12-09 23:15:01.158497+03	{"alp": 79, "alt": 46, "ast": 24}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
462	314	Thyroid Panel	LAB729	2024-11-22 08:11:01.158497+03	2024-11-29 08:11:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
463	314	Ultrasound Abdomen	LAB981	2024-11-22 08:11:01.158497+03	2024-11-26 08:11:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
464	318	HbA1c Test	LAB211	2024-12-27 20:55:01.158497+03	2025-01-03 20:55:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
465	318	Lipid Profile	LAB185	2024-12-27 20:55:01.158497+03	2024-12-28 20:55:01.158497+03	{"hdl": 1.0, "ldl": 2.5, "cholesterol": 4.8}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
466	320	X-Ray Chest	LAB243	2025-10-31 06:26:01.158497+03	2025-11-02 06:26:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
467	321	HbA1c Test	LAB684	2025-06-24 15:18:01.158497+03	2025-06-25 15:18:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
468	321	Cardiac Enzymes	LAB877	2025-06-24 15:18:01.158497+03	2025-06-30 15:18:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
469	322	X-Ray Chest	LAB359	2025-07-02 06:10:01.158497+03	2025-07-09 06:10:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
470	322	Coagulation Panel	LAB240	2025-07-02 06:10:01.158497+03	2025-07-07 06:10:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
471	322	Blood Glucose Test	LAB973	2025-07-03 06:10:01.158497+03	2025-07-08 06:10:01.158497+03	{"glucose": 7.0}	{"glucose": "3.9-6.1"}
472	324	Lipid Profile	LAB446	2025-01-09 04:54:01.158497+03	2025-01-15 04:54:01.158497+03	{"hdl": 1.3, "ldl": 2.3, "cholesterol": 4.5}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
473	324	Liver Function Tests	LAB011	2025-01-09 04:54:01.158497+03	2025-01-13 04:54:01.158497+03	{"alp": 41, "alt": 37, "ast": 42}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
474	324	COVID-19 PCR	LAB183	2025-01-10 04:54:01.158497+03	2025-01-14 04:54:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
475	325	Liver Function Tests	LAB478	2025-01-05 01:35:01.158497+03	2025-01-11 01:35:01.158497+03	{"alp": 79, "alt": 40, "ast": 37}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
476	325	Allergy Test	LAB301	2025-01-04 01:35:01.158497+03	2025-01-07 01:35:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
477	325	Liver Function Tests	LAB650	2025-01-04 01:35:01.158497+03	2025-01-05 01:35:01.158497+03	{"alp": 78, "alt": 21, "ast": 41}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
478	326	Liver Function Tests	LAB123	2025-03-01 11:42:01.158497+03	2025-03-08 11:42:01.158497+03	{"alp": 61, "alt": 17, "ast": 40}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
479	326	Vitamin D Test	LAB900	2025-02-28 11:42:01.158497+03	2025-03-01 11:42:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
480	326	Coagulation Panel	LAB006	2025-03-01 11:42:01.158497+03	2025-03-08 11:42:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
481	328	Cardiac Enzymes	LAB157	2025-07-12 10:14:01.158497+03	2025-07-14 10:14:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
482	330	Coagulation Panel	LAB363	2025-04-29 15:14:01.158497+03	2025-05-03 15:14:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
483	331	Ultrasound Abdomen	LAB601	2025-09-25 07:32:01.158497+03	2025-09-27 07:32:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
484	331	Lipid Profile	LAB337	2025-09-25 07:32:01.158497+03	2025-09-30 07:32:01.158497+03	{"hdl": 1.8, "ldl": 2.0, "cholesterol": 4.8}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
485	331	Renal Function Test	LAB026	2025-09-24 07:32:01.158497+03	2025-09-30 07:32:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
486	332	Spirometry	LAB575	2025-09-15 02:08:01.158497+03	2025-09-20 02:08:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
487	332	X-Ray Chest	LAB827	2025-09-14 02:08:01.158497+03	2025-09-16 02:08:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
488	333	Coagulation Panel	LAB283	2025-10-30 06:54:01.158497+03	2025-11-05 06:54:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
489	334	MRI Spine	LAB324	2025-08-05 19:12:01.158497+03	2025-08-06 19:12:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
490	334	Lipid Profile	LAB061	2025-08-04 19:12:01.158497+03	2025-08-09 19:12:01.158497+03	{"hdl": 1.1, "ldl": 3.8, "cholesterol": 5.2}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
491	334	Spirometry	LAB750	2025-08-05 19:12:01.158497+03	2025-08-09 19:12:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
492	335	MRI Spine	LAB754	2025-10-21 08:47:01.158497+03	2025-10-26 08:47:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
493	336	Complete Blood Count	LAB148	2025-07-08 18:35:01.158497+03	2025-07-10 18:35:01.158497+03	{"hgb": 154.4, "plt": 165, "rbc": 4.2, "wbc": 10.7}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
494	336	Liver Function Tests	LAB176	2025-07-07 18:35:01.158497+03	2025-07-08 18:35:01.158497+03	{"alp": 75, "alt": 36, "ast": 28}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
495	337	Stool Analysis	LAB380	2025-05-14 03:06:01.158497+03	2025-05-18 03:06:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
496	337	Ultrasound Abdomen	LAB022	2025-05-14 03:06:01.158497+03	2025-05-17 03:06:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
497	338	COVID-19 PCR	LAB034	2025-11-03 10:15:01.158497+03	2025-11-07 10:15:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
498	338	Allergy Test	LAB963	2025-11-04 10:15:01.158497+03	2025-11-05 10:15:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
499	339	ECG	LAB803	2024-12-14 18:10:01.158497+03	2024-12-17 18:10:01.158497+03	{"rate": 66, "rhythm": "irregular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
500	339	COVID-19 PCR	LAB944	2024-12-14 18:10:01.158497+03	2024-12-20 18:10:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
501	340	Spirometry	LAB553	2025-06-22 03:49:01.158497+03	2025-06-27 03:49:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
502	340	Ultrasound Abdomen	LAB604	2025-06-22 03:49:01.158497+03	2025-06-27 03:49:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
503	340	HbA1c Test	LAB360	2025-06-22 03:49:01.158497+03	2025-06-23 03:49:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
504	342	Cardiac Enzymes	LAB133	2025-08-30 10:39:01.158497+03	2025-09-01 10:39:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
505	342	Lipid Profile	LAB321	2025-08-31 10:39:01.158497+03	2025-09-03 10:39:01.158497+03	{"hdl": 1.9, "ldl": 2.5, "cholesterol": 4.3}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
506	342	HbA1c Test	LAB453	2025-08-30 10:39:01.158497+03	2025-09-03 10:39:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
507	343	ECG	LAB658	2025-01-12 02:52:01.158497+03	2025-01-15 02:52:01.158497+03	{"rate": 79, "rhythm": "irregular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
508	343	Lipid Profile	LAB533	2025-01-13 02:52:01.158497+03	2025-01-18 02:52:01.158497+03	{"hdl": 1.3, "ldl": 3.9, "cholesterol": 3.0}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
509	344	Complete Blood Count	LAB266	2025-10-11 11:34:01.158497+03	2025-10-16 11:34:01.158497+03	{"hgb": 123.0, "plt": 327, "rbc": 5.4, "wbc": 11.0}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
510	344	COVID-19 PCR	LAB893	2025-10-11 11:34:01.158497+03	2025-10-12 11:34:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
511	345	CT Head	LAB437	2025-04-23 04:28:01.158497+03	2025-04-26 04:28:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
512	345	HbA1c Test	LAB688	2025-04-23 04:28:01.158497+03	2025-04-24 04:28:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
513	346	Coagulation Panel	LAB271	2025-04-28 09:32:01.158497+03	2025-05-04 09:32:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
514	346	Thyroid Panel	LAB628	2025-04-28 09:32:01.158497+03	2025-05-04 09:32:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
515	347	HbA1c Test	LAB619	2025-09-13 02:20:01.158497+03	2025-09-19 02:20:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
516	347	Lipid Profile	LAB207	2025-09-13 02:20:01.158497+03	2025-09-18 02:20:01.158497+03	{"hdl": 1.8, "ldl": 4.0, "cholesterol": 5.7}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
517	348	Stool Analysis	LAB596	2025-08-20 12:41:01.158497+03	2025-08-24 12:41:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
518	348	CT Head	LAB259	2025-08-20 12:41:01.158497+03	2025-08-22 12:41:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
519	352	Lipid Profile	LAB601	2025-06-16 14:26:01.158497+03	2025-06-19 14:26:01.158497+03	{"hdl": 1.3, "ldl": 3.9, "cholesterol": 3.9}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
520	353	Thyroid Panel	LAB625	2025-04-30 01:19:01.158497+03	2025-05-03 01:19:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
521	353	COVID-19 PCR	LAB493	2025-04-29 01:19:01.158497+03	2025-05-04 01:19:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
522	353	Vitamin D Test	LAB735	2025-04-29 01:19:01.158497+03	2025-05-02 01:19:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
523	354	Ultrasound Abdomen	LAB887	2025-08-20 21:49:01.158497+03	2025-08-27 21:49:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
524	354	Urinalysis	LAB155	2025-08-20 21:49:01.158497+03	2025-08-21 21:49:01.158497+03	{"color": "amber", "glucose": 0.33, "protein": 0.10, "leukocytes": 2}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
525	355	Thyroid Panel	LAB802	2024-12-26 18:01:01.158497+03	2025-01-01 18:01:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
526	355	Cardiac Enzymes	LAB025	2024-12-26 18:01:01.158497+03	2024-12-28 18:01:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
527	355	Allergy Test	LAB110	2024-12-26 18:01:01.158497+03	2025-01-01 18:01:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
528	357	Vitamin D Test	LAB333	2025-06-16 00:09:01.158497+03	2025-06-19 00:09:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
529	357	Lipid Profile	LAB657	2025-06-16 00:09:01.158497+03	2025-06-23 00:09:01.158497+03	{"hdl": 1.6, "ldl": 2.6, "cholesterol": 4.8}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
530	357	Lipid Profile	LAB369	2025-06-17 00:09:01.158497+03	2025-06-23 00:09:01.158497+03	{"hdl": 1.5, "ldl": 3.9, "cholesterol": 4.0}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
531	358	Coagulation Panel	LAB798	2025-07-07 10:08:01.158497+03	2025-07-13 10:08:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
532	358	Spirometry	LAB835	2025-07-08 10:08:01.158497+03	2025-07-11 10:08:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
533	359	Cardiac Enzymes	LAB219	2025-10-04 00:06:01.158497+03	2025-10-07 00:06:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
534	359	Stool Analysis	LAB544	2025-10-04 00:06:01.158497+03	2025-10-07 00:06:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
535	359	Vitamin D Test	LAB665	2025-10-03 00:06:01.158497+03	2025-10-05 00:06:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
536	360	ECG	LAB439	2025-10-04 15:12:01.158497+03	2025-10-06 15:12:01.158497+03	{"rate": 67, "rhythm": "irregular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
537	360	COVID-19 PCR	LAB917	2025-10-05 15:12:01.158497+03	2025-10-06 15:12:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
538	360	X-Ray Chest	LAB934	2025-10-04 15:12:01.158497+03	2025-10-08 15:12:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
539	361	Vitamin D Test	LAB539	2025-05-11 02:47:01.158497+03	2025-05-16 02:47:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
540	361	Ultrasound Abdomen	LAB759	2025-05-12 02:47:01.158497+03	2025-05-17 02:47:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
541	361	Lipid Profile	LAB660	2025-05-11 02:47:01.158497+03	2025-05-17 02:47:01.158497+03	{"hdl": 1.0, "ldl": 3.5, "cholesterol": 3.4}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
542	362	Coagulation Panel	LAB921	2025-11-10 08:08:01.158497+03	2025-11-15 08:08:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
543	362	Cardiac Enzymes	LAB881	2025-11-09 08:08:01.158497+03	2025-11-14 08:08:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
544	365	Complete Blood Count	LAB243	2025-02-05 10:57:01.158497+03	2025-02-10 10:57:01.158497+03	{"hgb": 120.8, "plt": 175, "rbc": 5.7, "wbc": 8.4}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
545	365	CT Head	LAB893	2025-02-05 10:57:01.158497+03	2025-02-09 10:57:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
546	365	Blood Glucose Test	LAB129	2025-02-05 10:57:01.158497+03	2025-02-12 10:57:01.158497+03	{"glucose": 5.4}	{"glucose": "3.9-6.1"}
547	366	Blood Glucose Test	LAB369	2025-02-02 06:56:01.158497+03	2025-02-04 06:56:01.158497+03	{"glucose": 8.9}	{"glucose": "3.9-6.1"}
548	366	Ultrasound Abdomen	LAB304	2025-02-03 06:56:01.158497+03	2025-02-08 06:56:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
549	366	Vitamin D Test	LAB510	2025-02-03 06:56:01.158497+03	2025-02-09 06:56:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
550	367	Complete Blood Count	LAB792	2025-10-10 14:21:01.158497+03	2025-10-14 14:21:01.158497+03	{"hgb": 150.4, "plt": 232, "rbc": 5.5, "wbc": 8.9}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
551	368	Thyroid Panel	LAB988	2025-09-05 16:38:01.158497+03	2025-09-09 16:38:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
552	368	Blood Glucose Test	LAB069	2025-09-05 16:38:01.158497+03	2025-09-09 16:38:01.158497+03	{"glucose": 8.3}	{"glucose": "3.9-6.1"}
553	368	X-Ray Chest	LAB353	2025-09-06 16:38:01.158497+03	2025-09-13 16:38:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
554	371	Thyroid Panel	LAB407	2025-03-19 10:03:01.158497+03	2025-03-25 10:03:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
555	372	COVID-19 PCR	LAB325	2025-01-28 05:39:01.158497+03	2025-02-02 05:39:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
556	372	Stool Analysis	LAB165	2025-01-27 05:39:01.158497+03	2025-02-02 05:39:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
557	375	Liver Function Tests	LAB881	2025-06-06 02:01:01.158497+03	2025-06-10 02:01:01.158497+03	{"alp": 110, "alt": 22, "ast": 38}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
558	375	Ultrasound Abdomen	LAB307	2025-06-06 02:01:01.158497+03	2025-06-09 02:01:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
559	376	COVID-19 PCR	LAB384	2025-10-06 10:44:01.158497+03	2025-10-10 10:44:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
560	376	MRI Spine	LAB813	2025-10-05 10:44:01.158497+03	2025-10-09 10:44:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
561	377	Cardiac Enzymes	LAB071	2024-12-02 14:38:01.158497+03	2024-12-05 14:38:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
562	378	Renal Function Test	LAB375	2025-08-09 11:45:01.158497+03	2025-08-12 11:45:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
563	378	Vitamin D Test	LAB395	2025-08-10 11:45:01.158497+03	2025-08-15 11:45:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
564	378	Thyroid Panel	LAB709	2025-08-09 11:45:01.158497+03	2025-08-13 11:45:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
565	379	Thyroid Panel	LAB441	2025-02-13 09:37:01.158497+03	2025-02-16 09:37:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
566	379	Spirometry	LAB431	2025-02-14 09:37:01.158497+03	2025-02-19 09:37:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
567	380	COVID-19 PCR	LAB699	2024-12-19 00:41:01.158497+03	2024-12-22 00:41:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
568	380	Blood Glucose Test	LAB800	2024-12-18 00:41:01.158497+03	2024-12-22 00:41:01.158497+03	{"glucose": 6.0}	{"glucose": "3.9-6.1"}
569	380	ECG	LAB543	2024-12-19 00:41:01.158497+03	2024-12-24 00:41:01.158497+03	{"rate": 92, "rhythm": "regular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
570	382	Urinalysis	LAB556	2025-11-09 18:34:01.158497+03	2025-11-15 18:34:01.158497+03	{"color": "amber", "glucose": 0.33, "protein": 0.02, "leukocytes": 4}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
571	382	Stool Analysis	LAB752	2025-11-10 18:34:01.158497+03	2025-11-17 18:34:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
572	383	Liver Function Tests	LAB121	2025-08-29 19:26:01.158497+03	2025-09-04 19:26:01.158497+03	{"alp": 94, "alt": 45, "ast": 32}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
573	385	Complete Blood Count	LAB440	2025-07-15 17:11:01.158497+03	2025-07-20 17:11:01.158497+03	{"hgb": 151.2, "plt": 229, "rbc": 4.7, "wbc": 4.2}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
574	385	Liver Function Tests	LAB676	2025-07-14 17:11:01.158497+03	2025-07-17 17:11:01.158497+03	{"alp": 66, "alt": 30, "ast": 26}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
575	385	Cardiac Enzymes	LAB989	2025-07-15 17:11:01.158497+03	2025-07-16 17:11:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
576	386	Coagulation Panel	LAB719	2025-01-30 20:58:01.158497+03	2025-02-03 20:58:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
577	388	Blood Glucose Test	LAB831	2025-10-13 20:16:01.158497+03	2025-10-17 20:16:01.158497+03	{"glucose": 5.8}	{"glucose": "3.9-6.1"}
578	390	Blood Glucose Test	LAB408	2025-11-07 03:23:01.158497+03	2025-11-09 03:23:01.158497+03	{"glucose": 6.1}	{"glucose": "3.9-6.1"}
579	391	X-Ray Chest	LAB678	2025-10-09 02:32:01.158497+03	2025-10-13 02:32:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
580	392	Allergy Test	LAB995	2025-08-12 13:18:01.158497+03	2025-08-13 13:18:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
581	393	Cardiac Enzymes	LAB701	2025-09-02 18:20:01.158497+03	2025-09-09 18:20:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
582	393	CT Head	LAB515	2025-09-02 18:20:01.158497+03	2025-09-06 18:20:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
583	393	Allergy Test	LAB087	2025-09-01 18:20:01.158497+03	2025-09-03 18:20:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
584	394	MRI Spine	LAB568	2025-07-21 14:41:01.158497+03	2025-07-24 14:41:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
585	394	COVID-19 PCR	LAB278	2025-07-22 14:41:01.158497+03	2025-07-26 14:41:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
586	398	Lipid Profile	LAB491	2025-08-08 22:30:01.158497+03	2025-08-10 22:30:01.158497+03	{"hdl": 1.3, "ldl": 3.8, "cholesterol": 3.7}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
587	398	Thyroid Panel	LAB457	2025-08-09 22:30:01.158497+03	2025-08-14 22:30:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
588	398	ECG	LAB195	2025-08-09 22:30:01.158497+03	2025-08-16 22:30:01.158497+03	{"rate": 68, "rhythm": "irregular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
589	399	Blood Glucose Test	LAB253	2024-12-18 23:24:01.158497+03	2024-12-19 23:24:01.158497+03	{"glucose": 8.5}	{"glucose": "3.9-6.1"}
590	400	Cardiac Enzymes	LAB613	2025-04-28 09:06:01.158497+03	2025-05-04 09:06:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
591	401	ECG	LAB277	2025-05-30 12:12:01.158497+03	2025-06-01 12:12:01.158497+03	{"rate": 62, "rhythm": "regular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
592	401	CT Head	LAB002	2025-05-29 12:12:01.158497+03	2025-06-02 12:12:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
593	402	X-Ray Chest	LAB478	2025-05-28 21:15:01.158497+03	2025-06-04 21:15:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
594	402	Cardiac Enzymes	LAB308	2025-05-28 21:15:01.158497+03	2025-05-29 21:15:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
595	402	CT Head	LAB482	2025-05-29 21:15:01.158497+03	2025-06-05 21:15:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
596	403	Complete Blood Count	LAB900	2025-03-23 09:45:01.158497+03	2025-03-28 09:45:01.158497+03	{"hgb": 146.1, "plt": 231, "rbc": 4.4, "wbc": 13.7}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
597	403	X-Ray Chest	LAB871	2025-03-24 09:45:01.158497+03	2025-03-28 09:45:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
598	405	Complete Blood Count	LAB529	2025-07-26 06:52:01.158497+03	2025-07-28 06:52:01.158497+03	{"hgb": 133.5, "plt": 241, "rbc": 5.2, "wbc": 14.6}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
599	406	Blood Glucose Test	LAB026	2025-11-05 15:19:01.158497+03	2025-11-12 15:19:01.158497+03	{"glucose": 6.3}	{"glucose": "3.9-6.1"}
600	406	Cardiac Enzymes	LAB294	2025-11-04 15:19:01.158497+03	2025-11-10 15:19:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
601	406	Ultrasound Abdomen	LAB858	2025-11-05 15:19:01.158497+03	2025-11-08 15:19:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
602	407	Coagulation Panel	LAB376	2025-06-10 20:37:01.158497+03	2025-06-14 20:37:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
603	408	MRI Spine	LAB842	2025-06-02 17:22:01.158497+03	2025-06-06 17:22:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
604	408	Cardiac Enzymes	LAB596	2025-06-02 17:22:01.158497+03	2025-06-06 17:22:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
605	408	Complete Blood Count	LAB934	2025-06-02 17:22:01.158497+03	2025-06-09 17:22:01.158497+03	{"hgb": 113.2, "plt": 237, "rbc": 4.6, "wbc": 5.4}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
606	410	COVID-19 PCR	LAB598	2025-04-11 13:28:01.158497+03	2025-04-17 13:28:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
607	411	Allergy Test	LAB349	2025-08-12 21:58:01.158497+03	2025-08-13 21:58:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
608	412	Cardiac Enzymes	LAB888	2025-08-12 00:40:01.158497+03	2025-08-17 00:40:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
609	414	X-Ray Chest	LAB364	2025-06-15 13:26:01.158497+03	2025-06-19 13:26:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
610	414	Complete Blood Count	LAB660	2025-06-14 13:26:01.158497+03	2025-06-16 13:26:01.158497+03	{"hgb": 118.7, "plt": 286, "rbc": 5.5, "wbc": 7.3}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
611	414	Cardiac Enzymes	LAB550	2025-06-15 13:26:01.158497+03	2025-06-21 13:26:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
612	415	CT Head	LAB857	2025-09-14 09:34:01.158497+03	2025-09-21 09:34:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
613	416	Blood Glucose Test	LAB567	2025-08-04 09:33:01.158497+03	2025-08-07 09:33:01.158497+03	{"glucose": 6.6}	{"glucose": "3.9-6.1"}
614	417	CT Head	LAB565	2025-10-12 22:57:01.158497+03	2025-10-16 22:57:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
615	417	Blood Glucose Test	LAB884	2025-10-12 22:57:01.158497+03	2025-10-14 22:57:01.158497+03	{"glucose": 5.4}	{"glucose": "3.9-6.1"}
616	417	Stool Analysis	LAB668	2025-10-13 22:57:01.158497+03	2025-10-19 22:57:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
617	418	Spirometry	LAB788	2024-12-11 05:41:01.158497+03	2024-12-16 05:41:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
618	420	Renal Function Test	LAB673	2025-05-20 08:51:01.158497+03	2025-05-27 08:51:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
619	423	ECG	LAB279	2025-04-07 03:15:01.158497+03	2025-04-12 03:15:01.158497+03	{"rate": 94, "rhythm": "regular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
620	425	Ultrasound Abdomen	LAB788	2025-03-12 00:09:01.158497+03	2025-03-16 00:09:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
621	425	Cardiac Enzymes	LAB846	2025-03-13 00:09:01.158497+03	2025-03-14 00:09:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
622	426	Liver Function Tests	LAB635	2025-02-06 16:57:01.158497+03	2025-02-10 16:57:01.158497+03	{"alp": 111, "alt": 36, "ast": 42}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
623	426	Liver Function Tests	LAB875	2025-02-06 16:57:01.158497+03	2025-02-09 16:57:01.158497+03	{"alp": 124, "alt": 15, "ast": 33}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
624	426	ECG	LAB943	2025-02-05 16:57:01.158497+03	2025-02-12 16:57:01.158497+03	{"rate": 65, "rhythm": "sinus", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
625	428	Thyroid Panel	LAB161	2024-12-14 04:40:01.158497+03	2024-12-18 04:40:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
626	429	Vitamin D Test	LAB866	2025-10-19 07:58:01.158497+03	2025-10-26 07:58:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
627	429	X-Ray Chest	LAB457	2025-10-19 07:58:01.158497+03	2025-10-23 07:58:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
628	430	ECG	LAB458	2025-11-09 19:21:01.158497+03	2025-11-11 19:21:01.158497+03	{"rate": 64, "rhythm": "sinus", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
629	430	Coagulation Panel	LAB121	2025-11-10 19:21:01.158497+03	2025-11-17 19:21:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
630	430	Cardiac Enzymes	LAB054	2025-11-09 19:21:01.158497+03	2025-11-15 19:21:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
631	431	X-Ray Chest	LAB378	2025-09-07 11:30:01.158497+03	2025-09-08 11:30:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
632	431	ECG	LAB200	2025-09-07 11:30:01.158497+03	2025-09-11 11:30:01.158497+03	{"rate": 75, "rhythm": "regular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
633	431	MRI Spine	LAB983	2025-09-07 11:30:01.158497+03	2025-09-14 11:30:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
634	432	Lipid Profile	LAB309	2025-07-11 10:12:01.158497+03	2025-07-17 10:12:01.158497+03	{"hdl": 1.9, "ldl": 3.4, "cholesterol": 3.1}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
635	432	Ultrasound Abdomen	LAB402	2025-07-10 10:12:01.158497+03	2025-07-14 10:12:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
636	432	Stool Analysis	LAB083	2025-07-10 10:12:01.158497+03	2025-07-15 10:12:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
637	435	Vitamin D Test	LAB938	2025-10-11 03:02:01.158497+03	2025-10-17 03:02:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
638	435	MRI Spine	LAB966	2025-10-10 03:02:01.158497+03	2025-10-16 03:02:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
639	437	Urinalysis	LAB478	2025-05-02 01:43:01.158497+03	2025-05-03 01:43:01.158497+03	{"color": "amber", "glucose": 0.38, "protein": 0.01, "leukocytes": 3}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
640	438	Vitamin D Test	LAB780	2025-06-18 14:05:01.158497+03	2025-06-25 14:05:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
641	438	Complete Blood Count	LAB750	2025-06-19 14:05:01.158497+03	2025-06-20 14:05:01.158497+03	{"hgb": 147.6, "plt": 201, "rbc": 4.5, "wbc": 18.9}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
642	440	Complete Blood Count	LAB012	2025-02-05 20:09:01.158497+03	2025-02-09 20:09:01.158497+03	{"hgb": 121.3, "plt": 290, "rbc": 4.2, "wbc": 15.9}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
643	440	Stool Analysis	LAB292	2025-02-04 20:09:01.158497+03	2025-02-10 20:09:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
644	440	Liver Function Tests	LAB220	2025-02-05 20:09:01.158497+03	2025-02-06 20:09:01.158497+03	{"alp": 53, "alt": 30, "ast": 14}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
645	441	Thyroid Panel	LAB723	2025-04-13 11:31:01.158497+03	2025-04-15 11:31:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
646	441	HbA1c Test	LAB532	2025-04-13 11:31:01.158497+03	2025-04-16 11:31:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
647	441	Blood Glucose Test	LAB198	2025-04-13 11:31:01.158497+03	2025-04-16 11:31:01.158497+03	{"glucose": 6.0}	{"glucose": "3.9-6.1"}
648	442	Vitamin D Test	LAB842	2025-01-08 04:55:01.158497+03	2025-01-11 04:55:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
649	442	HbA1c Test	LAB334	2025-01-08 04:55:01.158497+03	2025-01-11 04:55:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
650	442	Thyroid Panel	LAB011	2025-01-09 04:55:01.158497+03	2025-01-12 04:55:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
651	443	Liver Function Tests	LAB782	2025-05-12 18:40:01.158497+03	2025-05-19 18:40:01.158497+03	{"alp": 110, "alt": 17, "ast": 36}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
652	443	Stool Analysis	LAB395	2025-05-13 18:40:01.158497+03	2025-05-16 18:40:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
653	443	Allergy Test	LAB998	2025-05-12 18:40:01.158497+03	2025-05-17 18:40:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
654	444	Thyroid Panel	LAB009	2025-10-07 03:19:01.158497+03	2025-10-08 03:19:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
655	444	Stool Analysis	LAB915	2025-10-07 03:19:01.158497+03	2025-10-08 03:19:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
656	445	ECG	LAB542	2025-04-12 22:19:01.158497+03	2025-04-16 22:19:01.158497+03	{"rate": 65, "rhythm": "irregular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
657	446	Coagulation Panel	LAB388	2025-01-16 22:18:01.158497+03	2025-01-22 22:18:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
658	446	Spirometry	LAB842	2025-01-17 22:18:01.158497+03	2025-01-18 22:18:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
659	446	Lipid Profile	LAB457	2025-01-17 22:18:01.158497+03	2025-01-20 22:18:01.158497+03	{"hdl": 1.6, "ldl": 2.3, "cholesterol": 6.0}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
660	447	Liver Function Tests	LAB094	2025-03-25 00:19:01.158497+03	2025-03-28 00:19:01.158497+03	{"alp": 57, "alt": 47, "ast": 30}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
661	447	Vitamin D Test	LAB041	2025-03-25 00:19:01.158497+03	2025-03-27 00:19:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
662	447	COVID-19 PCR	LAB324	2025-03-25 00:19:01.158497+03	2025-04-01 00:19:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
663	449	Allergy Test	LAB897	2025-02-02 15:40:01.158497+03	2025-02-04 15:40:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
664	450	Urinalysis	LAB531	2024-12-25 06:46:01.158497+03	2024-12-31 06:46:01.158497+03	{"color": "straw", "glucose": 0.27, "protein": 0.02, "leukocytes": 4}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
665	451	Stool Analysis	LAB241	2025-04-17 01:43:01.158497+03	2025-04-23 01:43:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
666	452	MRI Spine	LAB276	2024-11-21 21:17:01.158497+03	2024-11-24 21:17:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
667	453	MRI Spine	LAB626	2025-01-06 16:56:01.158497+03	2025-01-07 16:56:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
668	453	Coagulation Panel	LAB022	2025-01-07 16:56:01.158497+03	2025-01-13 16:56:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
669	453	CT Head	LAB929	2025-01-07 16:56:01.158497+03	2025-01-11 16:56:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
670	454	Cardiac Enzymes	LAB634	2025-01-19 07:33:01.158497+03	2025-01-22 07:33:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
671	455	Ultrasound Abdomen	LAB885	2024-12-27 05:49:01.158497+03	2025-01-01 05:49:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
672	456	COVID-19 PCR	LAB279	2025-07-14 04:47:01.158497+03	2025-07-19 04:47:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
673	456	MRI Spine	LAB755	2025-07-14 04:47:01.158497+03	2025-07-17 04:47:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
674	457	MRI Spine	LAB068	2025-07-07 17:01:01.158497+03	2025-07-12 17:01:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
675	457	Blood Glucose Test	LAB034	2025-07-07 17:01:01.158497+03	2025-07-09 17:01:01.158497+03	{"glucose": 5.9}	{"glucose": "3.9-6.1"}
676	458	Thyroid Panel	LAB818	2025-11-15 16:54:01.158497+03	2025-11-20 16:54:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
677	459	COVID-19 PCR	LAB077	2025-04-24 13:30:01.158497+03	2025-04-28 13:30:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
678	459	Spirometry	LAB607	2025-04-24 13:30:01.158497+03	2025-04-26 13:30:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
679	459	Cardiac Enzymes	LAB457	2025-04-25 13:30:01.158497+03	2025-04-28 13:30:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
680	464	MRI Spine	LAB363	2024-12-16 15:03:01.158497+03	2024-12-21 15:03:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
681	464	Renal Function Test	LAB260	2024-12-15 15:03:01.158497+03	2024-12-18 15:03:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
682	464	Renal Function Test	LAB875	2024-12-16 15:03:01.158497+03	2024-12-22 15:03:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
683	465	Ultrasound Abdomen	LAB935	2025-01-01 18:21:01.158497+03	2025-01-07 18:21:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
684	466	Allergy Test	LAB150	2025-09-27 20:42:01.158497+03	2025-10-03 20:42:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
685	466	HbA1c Test	LAB874	2025-09-28 20:42:01.158497+03	2025-10-05 20:42:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
686	466	Cardiac Enzymes	LAB658	2025-09-28 20:42:01.158497+03	2025-10-03 20:42:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
687	468	Liver Function Tests	LAB578	2025-01-19 02:49:01.158497+03	2025-01-22 02:49:01.158497+03	{"alp": 78, "alt": 49, "ast": 25}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
688	468	HbA1c Test	LAB692	2025-01-18 02:49:01.158497+03	2025-01-19 02:49:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
689	469	Renal Function Test	LAB652	2025-09-28 20:24:01.158497+03	2025-09-30 20:24:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
690	470	Lipid Profile	LAB236	2025-05-25 07:37:01.158497+03	2025-05-27 07:37:01.158497+03	{"hdl": 1.4, "ldl": 3.2, "cholesterol": 3.3}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
691	471	Spirometry	LAB918	2025-02-13 17:04:01.158497+03	2025-02-20 17:04:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
692	471	Thyroid Panel	LAB785	2025-02-13 17:04:01.158497+03	2025-02-17 17:04:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
693	471	COVID-19 PCR	LAB811	2025-02-12 17:04:01.158497+03	2025-02-17 17:04:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
694	472	Stool Analysis	LAB607	2025-08-12 14:48:01.158497+03	2025-08-16 14:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
695	472	X-Ray Chest	LAB868	2025-08-12 14:48:01.158497+03	2025-08-13 14:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
696	472	Liver Function Tests	LAB172	2025-08-13 14:48:01.158497+03	2025-08-16 14:48:01.158497+03	{"alp": 99, "alt": 45, "ast": 12}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
697	479	Complete Blood Count	LAB633	2025-01-08 13:48:01.158497+03	2025-01-09 13:48:01.158497+03	{"hgb": 145.7, "plt": 301, "rbc": 5.9, "wbc": 16.1}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
698	479	Spirometry	LAB304	2025-01-08 13:48:01.158497+03	2025-01-14 13:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
699	480	Liver Function Tests	LAB660	2025-03-10 17:40:01.158497+03	2025-03-17 17:40:01.158497+03	{"alp": 107, "alt": 45, "ast": 33}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
700	480	ECG	LAB093	2025-03-11 17:40:01.158497+03	2025-03-16 17:40:01.158497+03	{"rate": 68, "rhythm": "regular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
701	481	Spirometry	LAB103	2024-12-09 03:48:01.158497+03	2024-12-15 03:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
702	481	Allergy Test	LAB504	2024-12-09 03:48:01.158497+03	2024-12-11 03:48:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
703	482	COVID-19 PCR	LAB062	2024-12-10 18:26:01.158497+03	2024-12-17 18:26:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
704	482	Lipid Profile	LAB530	2024-12-10 18:26:01.158497+03	2024-12-11 18:26:01.158497+03	{"hdl": 1.6, "ldl": 3.7, "cholesterol": 3.1}	{"hdl": ">1.0", "ldl": "<3.0", "cholesterol": "<5.2"}
705	482	Urinalysis	LAB180	2024-12-10 18:26:01.158497+03	2024-12-12 18:26:01.158497+03	{"color": "amber", "glucose": 0.03, "protein": 0.08, "leukocytes": 1}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
706	484	Liver Function Tests	LAB999	2025-05-09 12:09:01.158497+03	2025-05-15 12:09:01.158497+03	{"alp": 54, "alt": 43, "ast": 23}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
707	484	Cardiac Enzymes	LAB528	2025-05-08 12:09:01.158497+03	2025-05-09 12:09:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
708	484	Allergy Test	LAB251	2025-05-09 12:09:01.158497+03	2025-05-16 12:09:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
709	485	Coagulation Panel	LAB025	2025-05-08 06:10:01.158497+03	2025-05-12 06:10:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
710	486	Renal Function Test	LAB252	2024-11-22 23:53:01.158497+03	2024-11-26 23:53:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
711	489	Spirometry	LAB470	2025-09-28 23:36:01.158497+03	2025-10-01 23:36:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
712	489	Ultrasound Abdomen	LAB029	2025-09-28 23:36:01.158497+03	2025-10-03 23:36:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
713	489	Urinalysis	LAB891	2025-09-28 23:36:01.158497+03	2025-09-29 23:36:01.158497+03	{"color": "straw", "glucose": 0.30, "protein": 0.02, "leukocytes": 0}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
714	490	Urinalysis	LAB116	2025-04-12 19:30:01.158497+03	2025-04-17 19:30:01.158497+03	{"color": "straw", "glucose": 0.12, "protein": 0.03, "leukocytes": 3}	{"color": "yellow", "glucose": "0", "protein": "0-0.03", "leukocytes": "0-5"}
715	490	Spirometry	LAB161	2025-04-13 19:30:01.158497+03	2025-04-16 19:30:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
716	491	Blood Glucose Test	LAB833	2025-01-01 22:32:01.158497+03	2025-01-05 22:32:01.158497+03	{"glucose": 7.0}	{"glucose": "3.9-6.1"}
717	491	Liver Function Tests	LAB627	2025-01-02 22:32:01.158497+03	2025-01-06 22:32:01.158497+03	{"alp": 75, "alt": 37, "ast": 21}	{"alp": "40-130", "alt": "10-40", "ast": "10-35"}
718	491	Thyroid Panel	LAB367	2025-01-01 22:32:01.158497+03	2025-01-02 22:32:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
719	492	Ultrasound Abdomen	LAB739	2025-07-23 16:59:01.158497+03	2025-07-27 16:59:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
720	492	COVID-19 PCR	LAB123	2025-07-24 16:59:01.158497+03	2025-07-28 16:59:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
721	493	Allergy Test	LAB454	2025-07-05 06:10:01.158497+03	2025-07-09 06:10:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
722	493	Complete Blood Count	LAB541	2025-07-05 06:10:01.158497+03	2025-07-12 06:10:01.158497+03	{"hgb": 151.7, "plt": 209, "rbc": 4.9, "wbc": 15.5}	{"hgb": "120-160", "plt": "150-450", "rbc": "4.5-6.0", "wbc": "4.0-11.0"}
723	493	Stool Analysis	LAB261	2025-07-06 06:10:01.158497+03	2025-07-13 06:10:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
724	494	ECG	LAB531	2024-12-01 08:30:01.158497+03	2024-12-05 08:30:01.158497+03	{"rate": 74, "rhythm": "irregular", "conclusion": "normal"}	{"rate": "60-100", "rhythm": "sinus"}
725	496	HbA1c Test	LAB831	2025-02-28 22:20:01.158497+03	2025-03-02 22:20:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
726	497	Renal Function Test	LAB491	2025-06-03 17:50:01.158497+03	2025-06-08 17:50:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
727	497	X-Ray Chest	LAB060	2025-06-04 17:50:01.158497+03	2025-06-08 17:50:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
728	498	COVID-19 PCR	LAB487	2025-04-03 23:20:01.158497+03	2025-04-09 23:20:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
729	498	Cardiac Enzymes	LAB659	2025-04-02 23:20:01.158497+03	2025-04-08 23:20:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
730	498	Renal Function Test	LAB085	2025-04-02 23:20:01.158497+03	2025-04-09 23:20:01.158497+03	{"result": "within normal limits"}	{"reference": "standard values"}
\.


--
-- Data for Name: medical_workers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.medical_workers (worker_id, clinic_id, specialization_id, first_name, last_name, phone, email, experience_years, salary, hire_date) FROM stdin;
1	3	4	Robert	Smith	+74031902156	nusystem3365@medical.org	33	134600.79	1997-10-28
2	1	10	Ava	Brown	+74602724827	rhosystem312@medical.org	20	149377.26	2009-05-21
3	3	1	Thomas	Gonzalez	+73262183902	rhosource4422@medical.org	29	191589.25	2000-04-20
4	2	4	Thomas	Gonzalez	+71906844979	philine1709@medical.org	14	94272.62	2013-10-28
5	2	4	Amelia	Wilson	+70639629294	kappabase1474@medical.org	41	229607.60	1992-06-04
6	1	9	Ava	Martinez	+78478064442	vitalpoint3183@medical.org	25	171099.84	2007-07-26
7	2	3	Mia	Brown	+73674498673	psilink9247@medical.org	25	165091.58	2003-07-19
8	1	2	William	Moore	+70740765276	clinicscope6637@medical.org	39	221832.64	1995-04-30
9	1	8	Charlotte	Hernandez	+72810982963	chisource9237@medical.org	31	171207.27	1994-06-01
10	3	2	James	Taylor	+73628283593	healscope3257@medical.org	11	103308.92	2018-07-11
11	1	10	Isabella	Rodriguez	+72724210968	alphascope6392@medical.org	33	169394.59	1995-07-20
12	2	1	Daniel	Johnson	+72670299027	thetasource8572@medical.org	21	162845.34	2006-07-04
13	1	7	John	Jackson	+75342100373	iotasystem7986@medical.org	17	114791.16	2008-03-01
14	3	5	Amelia	Martinez	+76818585520	lifepoint707@medical.org	14	138469.46	2016-06-05
15	2	3	Robert	Garcia	+70274798919	healsite2346@medical.org	29	176282.78	2002-11-06
16	2	9	Harper	Rodriguez	+78581911767	iotafield4847@medical.org	39	217282.43	1992-01-06
17	2	9	Emma	Miller	+70086897297	sigmasite6986@medical.org	30	164837.26	2004-01-04
18	2	4	Christopher	Thomas	+79681500478	zetapoint3194@medical.org	9	106589.23	2017-02-20
19	2	4	Sophia	Gonzalez	+79587178797	surgeonzone3009@medical.org	4	54714.05	2023-09-05
20	3	3	Ava	Williams	+78709834394	upsiloncenter4741@medical.org	24	192343.71	2007-04-04
21	1	4	Daniel	Brown	+74351948182	curepoint5942@medical.org	14	85827.26	2013-03-29
22	1	6	Amelia	Smith	+79387965493	deltamark3027@medical.org	15	80062.87	2014-08-06
23	1	9	David	Miller	+74603735569	surgeonspot8110@medical.org	11	75446.10	2021-05-12
24	3	1	Ava	Martin	+78367526340	sigmalink4804@medical.org	36	221797.83	1990-11-30
25	3	9	Mia	Wilson	+76540576664	betaspot2148@medical.org	3	66036.05	2022-04-17
26	3	1	Christopher	Hernandez	+76756383557	thetafield3078@medical.org	14	116556.95	2013-08-01
27	2	7	Daniel	Thomas	+76550134662	epsilonhub6130@medical.org	25	160147.80	2000-09-01
28	1	4	James	Taylor	+75275426676	iotaspot2555@medical.org	37	215518.54	1997-08-19
29	3	4	Isabella	Martinez	+71389828368	etanode945@medical.org	19	132895.50	2016-07-24
30	2	6	Isabella	Martin	+73671841234	mugroup7852@medical.org	14	103182.95	2017-10-15
31	2	10	Mia	Garcia	+71568235989	xisource3932@medical.org	17	89917.06	2012-11-30
32	1	8	Charlotte	Lopez	+79943310896	aidsite2985@medical.org	12	113853.08	2014-06-24
33	3	4	Charlotte	Johnson	+71192052797	alphahub9540@medical.org	17	131027.73	2011-01-20
34	1	3	Robert	Taylor	+72862333217	healthnet7877@medical.org	8	50000.00	2018-12-15
35	2	3	Charlotte	Anderson	+72468635567	etafield8918@medical.org	23	192522.02	2008-01-07
36	3	10	Olivia	Moore	+72431364001	kappascope1590@medical.org	26	151457.31	2009-09-28
37	1	2	Evelyn	Taylor	+79171353669	betahub4700@medical.org	28	169492.28	2006-07-23
38	3	10	Harper	Moore	+77322372911	psinode6982@medical.org	15	124459.99	2011-06-24
39	2	4	Michael	Davis	+70675396685	piunit3855@medical.org	11	98268.07	2014-10-08
40	1	2	David	Smith	+77715400742	nuspot6859@medical.org	30	142432.20	1996-12-01
41	2	4	Sophia	Smith	+75229289538	medicalnet2370@medical.org	31	231998.80	1994-11-17
42	2	9	Olivia	Lopez	+70516622699	doctorspot5652@medical.org	3	50000.00	2025-01-15
43	3	9	Olivia	Taylor	+71134219971	aidline2724@medical.org	31	160734.14	1997-10-30
44	3	8	Robert	Lopez	+72915598337	wellnessspot7288@medical.org	9	80978.23	2019-11-28
45	1	6	Richard	Jackson	+73853447062	zetasystem9518@medical.org	7	90240.51	2021-04-02
46	1	3	Mia	Taylor	+76647303277	betacenter8435@medical.org	39	256232.41	1993-07-20
47	2	6	Michael	Gonzalez	+77474887088	thetaline7124@medical.org	27	150451.72	2005-09-24
48	2	4	John	Davis	+78754930057	aidspot9961@medical.org	11	129407.05	2021-03-30
49	3	2	Charlotte	Anderson	+78562328569	doctormark4430@medical.org	34	165905.86	1992-05-13
50	2	4	James	Jackson	+74056672547	psimark1447@medical.org	12	139464.82	2014-12-07
51	3	3	David	Miller	+79699743891	surgeonnode8204@medical.org	13	85083.31	2012-09-08
52	3	6	Mia	Miller	+70353157248	careline4581@medical.org	32	184890.25	1996-09-10
53	3	5	Harper	Miller	+77840081856	iotabase1272@medical.org	20	137882.76	2005-02-08
54	2	6	Sophia	Martinez	+74496297387	curehub6867@medical.org	24	108386.56	2001-03-03
55	1	6	Harper	Smith	+78542698114	hospitalbase1491@medical.org	6	50000.00	2023-12-14
56	2	4	Daniel	Anderson	+71924887341	upsilonmark3002@medical.org	17	149081.43	2017-02-12
57	2	5	Mia	Rodriguez	+79212922830	sigmaline2948@medical.org	14	65226.04	2015-10-15
58	2	6	Michael	Davis	+70053810511	doctorview1345@medical.org	25	137979.10	2000-03-23
59	2	9	Sophia	Thomas	+75283554311	deltalink9932@medical.org	39	188406.31	1993-07-08
60	3	9	Harper	Garcia	+71904438479	lifecenter7715@medical.org	6	60748.65	2024-10-03
61	1	4	Christopher	Taylor	+78420410006	muview2308@medical.org	28	122255.38	1999-07-01
62	3	4	Michael	Jones	+76704046552	chipoint8473@medical.org	21	146638.69	2004-03-09
63	1	9	David	Martinez	+73989995871	omegasource8007@medical.org	10	79811.39	2018-10-17
64	3	5	Olivia	Martinez	+77391300016	kappasystem4836@medical.org	23	179401.33	2005-08-06
\.


--
-- Data for Name: patients; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.patients (patient_id, first_name, last_name, birth_date, gender, phone, email, passport_series, passport_number, snils, address, created_at) FROM stdin;
1	Jennifer	Taylor	1953-12-26	F	+77586602643	jennifer.taylor574@hotmail.com	5024	960440	497-384-064 03	132 Main St, Samara, Russia	2025-11-18 20:47:11.711173+03
2	Karen	Jones	1946-03-02	M	+76418874033	karen.jones974@outlook.com	3096	794257	555-109-186 65	162 Elm St, Rostov-on-Don, Russia	2025-11-18 20:47:11.711173+03
3	Robert	Williams	1972-05-01	M	+73641937664	robert.williams680@outlook.com	6162	903535	545-539-220 18	36 Pine Rd, Yekaterinburg, Russia	2025-11-18 20:47:11.711173+03
4	Karen	Johnson	1949-10-05	M	+71470981652	karen.johnson302@gmail.com	9847	304601	127-849-262 91	60 Aspen St, Moscow, Russia	2025-11-18 20:47:11.711173+03
5	Thomas	Miller	2005-09-16	M	+75576168751	thomas.miller197@gmail.com	5909	155681	957-715-247 51	51 Spruce Way, Omsk, Russia	2025-11-18 20:47:11.711173+03
6	Richard	Smith	1946-05-22	F	+74911118093	richard.smith389@gmail.com	7024	044454	808-511-198 44	110 Pine Rd, Yekaterinburg, Russia	2025-11-18 20:47:11.711173+03
7	Sarah	Davis	2006-01-15	F	+78118011658	sarah.davis16@yahoo.com	8115	237093	171-899-695 97	197 Pine Rd, Rostov-on-Don, Russia	2025-11-18 20:47:11.711173+03
8	Patricia	Taylor	1947-10-13	M	+73965310745	patricia.taylor882@hotmail.com	3485	950261	527-979-788 58	55 Pine Rd, Moscow, Russia	2025-11-18 20:47:11.711173+03
9	Richard	Moore	1954-10-01	M	+74566598830	richard.moore20@outlook.com	0796	763803	617-923-128 55	120 Spruce Way, Saint Petersburg, Russia	2025-11-18 20:47:11.711173+03
10	John	Thompson	1938-06-06	F	+77324666344	john.thompson332@yahoo.com	5043	837187	150-569-637 67	180 Elm St, Saint Petersburg, Russia	2025-11-18 20:47:11.711173+03
11	Barbara	Davis	1970-08-08	F	+76613983576	barbara.davis873@gmail.com	0931	355334	345-282-972 22	54 Main St, Novosibirsk, Russia	2025-11-18 20:47:11.711173+03
12	Mary	Johnson	1945-01-16	M	+72181483035	mary.johnson270@yahoo.com	4485	375613	599-071-578 19	155 Cedar Ln, Novosibirsk, Russia	2025-11-18 20:47:11.711173+03
13	Karen	Jackson	1940-12-10	M	+70430106761	karen.jackson483@hotmail.com	5309	231248	804-367-258 62	91 Aspen St, Kazan, Russia	2025-11-18 20:47:11.711173+03
14	Robert	Rodriguez	1952-01-08	M	+71452125157	robert.rodriguez129@outlook.com	1842	924218	154-623-924 89	131 Pine Rd, Novosibirsk, Russia	2025-11-18 20:47:11.711173+03
15	Karen	Martin	1940-02-18	M	+70786915967	karen.martin664@outlook.com	4775	597221	315-737-479 27	25 Spruce Way, Novosibirsk, Russia	2025-11-18 20:47:11.711173+03
16	Susan	Jackson	1966-08-13	F	+72469543768	susan.jackson706@gmail.com	4915	458927	570-369-029 80	37 Aspen St, Kazan, Russia	2025-11-18 20:47:11.711173+03
17	John	Smith	1953-01-13	F	+75625678797	john.smith307@hotmail.com	5084	568598	109-792-475 31	28 Willow Rd, Chelyabinsk, Russia	2025-11-18 20:47:11.711173+03
18	Karen	Moore	1957-06-25	M	+78800158412	karen.moore397@outlook.com	8764	580313	882-238-464 02	175 Maple Dr, Moscow, Russia	2025-11-18 20:47:11.711173+03
19	Charles	Garcia	2004-09-30	F	+73242396389	charles.garcia534@hotmail.com	6300	957354	307-907-357 71	123 Oak Ave, Omsk, Russia	2025-11-18 20:47:11.711173+03
20	William	Hernandez	2002-03-31	F	+73155238965	william.hernandez280@hotmail.com	1599	565133	249-299-259 22	6 Main St, Samara, Russia	2025-11-18 20:47:11.711173+03
21	Sarah	Thompson	1939-07-02	F	+78513847759	sarah.thompson835@gmail.com	7061	056686	340-790-314 80	98 Oak Ave, Samara, Russia	2025-11-18 20:47:11.711173+03
22	Thomas	Thompson	1949-08-12	M	+74327867864	thomas.thompson652@outlook.com	6765	546765	907-737-013 59	135 Birch St, Moscow, Russia	2025-11-18 20:47:11.711173+03
23	Charles	Johnson	1972-10-07	F	+77655243312	charles.johnson394@gmail.com	7132	057717	922-059-158 10	133 Birch St, Novosibirsk, Russia	2025-11-18 20:47:11.711173+03
24	Linda	Moore	2004-07-23	M	+76816669294	linda.moore373@outlook.com	3717	175417	906-814-187 71	26 Main St, Samara, Russia	2025-11-18 20:47:11.711173+03
25	Thomas	Thompson	2000-03-12	M	+70483041780	thomas.thompson815@yahoo.com	8045	159523	371-853-726 74	181 Cedar Ln, Nizhny Novgorod, Russia	2025-11-18 20:47:11.711173+03
26	Joseph	Wilson	1978-08-24	M	+79420413820	joseph.wilson338@yahoo.com	7812	063916	364-655-677 28	169 Pine Rd, Omsk, Russia	2025-11-18 20:47:11.711173+03
27	Joseph	Wilson	1965-09-11	F	+75759094207	joseph.wilson363@outlook.com	8181	559716	565-697-589 37	138 Elm St, Chelyabinsk, Russia	2025-11-18 20:47:11.711173+03
28	Joseph	Brown	1958-07-10	M	+79466086283	joseph.brown199@yahoo.com	0286	327262	476-137-712 39	56 Aspen St, Omsk, Russia	2025-11-18 20:47:11.711173+03
29	Sarah	Thomas	1960-04-21	M	+75848514865	sarah.thomas145@outlook.com	7540	107873	999-762-079 94	14 Oak Ave, Nizhny Novgorod, Russia	2025-11-18 20:47:11.711173+03
30	Jennifer	Williams	1968-07-30	F	+71263757442	jennifer.williams726@hotmail.com	2163	228525	496-955-096 46	166 Willow Rd, Yekaterinburg, Russia	2025-11-18 20:47:11.711173+03
31	Jennifer	Johnson	1969-04-28	F	+72846609519	jennifer.johnson775@yahoo.com	7134	191133	862-601-548 37	42 Oak Ave, Yekaterinburg, Russia	2025-11-18 20:47:11.711173+03
32	Jennifer	Garcia	1990-11-25	F	+76679800940	jennifer.garcia556@outlook.com	6307	953088	830-865-141 71	74 Oak Ave, Rostov-on-Don, Russia	2025-11-18 20:47:11.711173+03
33	John	Smith	1998-01-13	M	+77761387778	john.smith443@gmail.com	8142	760341	502-105-034 61	111 Cedar Ln, Omsk, Russia	2025-11-18 20:47:11.711173+03
34	John	Johnson	1996-01-28	F	+71413923497	john.johnson406@hotmail.com	3635	805377	836-786-154 55	135 Main St, Omsk, Russia	2025-11-18 20:47:11.711173+03
35	Thomas	Williams	1948-02-04	M	+74328977111	thomas.williams225@hotmail.com	7019	394448	982-581-078 74	45 Aspen St, Yekaterinburg, Russia	2025-11-18 20:47:11.711173+03
36	Barbara	Miller	1970-12-18	F	+79449931445	barbara.miller55@hotmail.com	4446	793192	233-675-193 69	58 Aspen St, Kazan, Russia	2025-11-18 20:47:11.711173+03
37	Joseph	Williams	1973-08-04	M	+76678359596	joseph.williams795@outlook.com	0692	241130	617-370-561 12	165 Main St, Rostov-on-Don, Russia	2025-11-18 20:47:11.711173+03
38	Sarah	Jones	1960-07-08	M	+70726089068	sarah.jones958@hotmail.com	9216	682811	857-853-441 19	38 Birch St, Samara, Russia	2025-11-18 20:47:11.711173+03
39	David	Brown	1987-10-17	M	+71050181859	david.brown419@gmail.com	0056	018828	633-018-192 48	43 Birch St, Novosibirsk, Russia	2025-11-18 20:47:11.711173+03
40	Joseph	Smith	1963-04-29	M	+75944743040	joseph.smith310@gmail.com	1830	340398	161-744-234 08	198 Elm St, Chelyabinsk, Russia	2025-11-18 20:47:11.711173+03
41	Sarah	Johnson	1950-05-15	M	+70448311757	sarah.johnson639@yahoo.com	4384	061323	615-554-987 40	33 Aspen St, Yekaterinburg, Russia	2025-11-18 20:47:11.711173+03
42	Susan	Anderson	1966-07-04	F	+74786537613	susan.anderson887@gmail.com	0039	546424	401-478-349 29	191 Elm St, Chelyabinsk, Russia	2025-11-18 20:47:11.711173+03
43	Joseph	Anderson	1967-11-15	M	+77867456486	joseph.anderson904@hotmail.com	3645	017520	170-877-165 84	48 Main St, Novosibirsk, Russia	2025-11-18 20:47:11.711173+03
44	David	Thomas	1981-05-12	F	+78281012323	david.thomas230@outlook.com	6696	093342	308-451-567 39	190 Oak Ave, Nizhny Novgorod, Russia	2025-11-18 20:47:11.711173+03
45	Sarah	Johnson	1936-10-21	F	+78084511773	sarah.johnson749@hotmail.com	5471	404459	668-807-709 18	30 Oak Ave, Moscow, Russia	2025-11-18 20:47:11.711173+03
46	Jessica	Jackson	1937-02-24	F	+79202546057	jessica.jackson46@hotmail.com	4406	585449	279-527-498 08	97 Willow Rd, Omsk, Russia	2025-11-18 20:47:11.711173+03
47	Michael	Thompson	1958-04-26	F	+73041009769	michael.thompson864@yahoo.com	4619	409428	466-017-154 42	36 Oak Ave, Novosibirsk, Russia	2025-11-18 20:47:11.711173+03
48	Linda	Johnson	1948-05-15	F	+77536395089	linda.johnson35@outlook.com	1933	643261	430-243-499 67	18 Willow Rd, Yekaterinburg, Russia	2025-11-18 20:47:11.711173+03
49	Karen	Wilson	1942-11-12	F	+73451314800	karen.wilson725@hotmail.com	8985	045389	595-877-272 06	92 Maple Dr, Yekaterinburg, Russia	2025-11-18 20:47:11.711173+03
50	Joseph	Smith	1963-11-02	M	+79367268709	joseph.smith146@yahoo.com	4501	201561	008-005-472 77	62 Oak Ave, Novosibirsk, Russia	2025-11-18 20:47:11.711173+03
51	Barbara	Moore	1973-09-03	M	+79215398272	barbara.moore399@hotmail.com	7897	540888	732-929-550 86	27 Willow Rd, Kazan, Russia	2025-11-18 20:47:11.711173+03
52	Richard	Miller	1936-12-07	M	+76059706641	richard.miller781@outlook.com	8270	847623	433-552-628 05	17 Maple Dr, Moscow, Russia	2025-11-18 20:47:11.711173+03
53	David	Moore	2000-05-10	F	+71902753439	david.moore281@outlook.com	9469	201373	757-118-657 16	82 Maple Dr, Chelyabinsk, Russia	2025-11-18 20:47:11.711173+03
54	Mary	Davis	1959-04-15	M	+73470447190	mary.davis873@gmail.com	4221	251410	871-920-673 09	169 Elm St, Rostov-on-Don, Russia	2025-11-18 20:47:11.711173+03
55	James	Moore	1958-05-19	F	+77496857983	james.moore768@gmail.com	2849	542255	606-612-104 35	30 Spruce Way, Nizhny Novgorod, Russia	2025-11-18 20:47:11.711173+03
56	Barbara	Taylor	1981-01-01	M	+70720045257	barbara.taylor126@hotmail.com	9246	177761	436-482-307 78	181 Birch St, Yekaterinburg, Russia	2025-11-18 20:47:11.711173+03
57	Jessica	Jackson	1969-03-03	M	+74439516080	jessica.jackson431@gmail.com	4012	576463	181-356-770 08	152 Elm St, Moscow, Russia	2025-11-18 20:47:11.711173+03
58	Charles	Davis	1939-12-18	F	+75808713332	charles.davis647@hotmail.com	6134	568096	590-512-007 19	191 Elm St, Yekaterinburg, Russia	2025-11-18 20:47:11.711173+03
59	Susan	Garcia	1945-05-21	M	+76745655802	susan.garcia170@yahoo.com	6564	092237	956-275-804 85	192 Aspen St, Novosibirsk, Russia	2025-11-18 20:47:11.711173+03
60	Jennifer	Martin	1997-07-11	M	+71083381363	jennifer.martin444@hotmail.com	7238	121456	469-626-993 53	70 Willow Rd, Chelyabinsk, Russia	2025-11-18 20:47:11.711173+03
61	Michael	Thompson	1961-02-23	M	+76765425670	michael.thompson836@outlook.com	8273	349342	393-012-002 52	31 Pine Rd, Saint Petersburg, Russia	2025-11-18 20:47:11.711173+03
62	Mary	Wilson	1990-11-21	M	+71004210345	mary.wilson862@hotmail.com	7624	943259	902-167-483 34	157 Spruce Way, Moscow, Russia	2025-11-18 20:47:11.711173+03
63	James	White	1992-03-16	F	+70887919361	james.white996@hotmail.com	9541	688800	697-739-730 35	7 Cedar Ln, Saint Petersburg, Russia	2025-11-18 20:47:11.711173+03
64	Elizabeth	Williams	1951-03-07	F	+76757373464	elizabeth.williams925@yahoo.com	1159	778616	433-413-410 67	83 Pine Rd, Saint Petersburg, Russia	2025-11-18 20:47:11.711173+03
65	Karen	Wilson	1948-10-01	F	+79567735501	karen.wilson704@outlook.com	5068	856349	634-111-392 46	17 Spruce Way, Nizhny Novgorod, Russia	2025-11-18 20:47:11.711173+03
66	James	Smith	1967-05-22	M	+77607401559	james.smith869@gmail.com	7192	728189	315-489-715 52	38 Oak Ave, Novosibirsk, Russia	2025-11-18 20:47:11.711173+03
67	Karen	Johnson	1947-06-29	F	+74899795908	karen.johnson198@gmail.com	5819	740468	268-365-484 88	107 Cedar Ln, Nizhny Novgorod, Russia	2025-11-18 20:47:11.711173+03
68	Jessica	Miller	1969-11-02	M	+72010215757	jessica.miller456@hotmail.com	1038	995907	876-307-769 65	184 Pine Rd, Yekaterinburg, Russia	2025-11-18 20:47:11.711173+03
69	Robert	Taylor	1991-08-07	F	+79191390260	robert.taylor637@outlook.com	3776	281773	605-168-788 58	51 Cedar Ln, Chelyabinsk, Russia	2025-11-18 20:47:11.711173+03
70	Sarah	Thomas	1958-07-28	M	+74175899743	sarah.thomas891@gmail.com	6832	840493	818-184-684 22	181 Spruce Way, Nizhny Novgorod, Russia	2025-11-18 20:47:11.711173+03
71	Jennifer	Davis	1953-01-31	F	+71069797460	jennifer.davis435@yahoo.com	7062	243111	489-742-690 09	57 Spruce Way, Yekaterinburg, Russia	2025-11-18 20:47:11.711173+03
72	Sarah	Taylor	1995-06-26	M	+74243643754	sarah.taylor970@yahoo.com	7126	340606	992-790-758 05	35 Spruce Way, Saint Petersburg, Russia	2025-11-18 20:47:11.711173+03
73	Mary	Hernandez	1985-11-22	F	+77243113207	mary.hernandez749@outlook.com	3646	672078	708-683-275 13	147 Aspen St, Yekaterinburg, Russia	2025-11-18 20:47:11.711173+03
74	Karen	Miller	1951-06-23	F	+75157953435	karen.miller187@yahoo.com	4399	303532	510-453-078 77	55 Aspen St, Yekaterinburg, Russia	2025-11-18 20:47:11.711173+03
75	John	Johnson	1962-06-05	M	+78217311676	john.johnson247@yahoo.com	4950	947128	574-329-729 68	149 Oak Ave, Chelyabinsk, Russia	2025-11-18 20:47:11.711173+03
76	Karen	Wilson	1957-12-30	F	+70195775107	karen.wilson622@yahoo.com	0739	837724	853-412-347 91	171 Maple Dr, Kazan, Russia	2025-11-18 20:47:11.711173+03
77	Barbara	Taylor	2002-06-02	M	+76918867314	barbara.taylor416@gmail.com	7745	123694	478-871-182 93	132 Maple Dr, Rostov-on-Don, Russia	2025-11-18 20:47:11.711173+03
78	Charles	Hernandez	2003-03-15	F	+76392626092	charles.hernandez145@outlook.com	5793	128038	735-302-183 64	90 Aspen St, Moscow, Russia	2025-11-18 20:47:11.711173+03
79	David	Smith	1981-12-23	F	+75559860571	david.smith845@outlook.com	8753	049873	852-599-775 94	6 Cedar Ln, Rostov-on-Don, Russia	2025-11-18 20:47:11.711173+03
80	Sarah	Wilson	2006-12-09	F	+72067557847	sarah.wilson327@outlook.com	3370	572614	735-940-466 32	106 Birch St, Kazan, Russia	2025-11-18 20:47:11.711173+03
81	Robert	Taylor	1998-01-16	M	+79367626950	robert.taylor457@yahoo.com	4608	550049	369-299-546 49	166 Willow Rd, Samara, Russia	2025-11-18 20:47:11.711173+03
82	Jennifer	Brown	1937-06-01	M	+77705509268	jennifer.brown835@hotmail.com	9001	821944	541-883-607 27	171 Aspen St, Rostov-on-Don, Russia	2025-11-18 20:47:11.711173+03
83	John	Taylor	1976-06-22	M	+71472423510	john.taylor730@yahoo.com	9864	859116	482-579-946 61	169 Main St, Samara, Russia	2025-11-18 20:47:11.711173+03
84	Jessica	Wilson	1988-05-02	M	+76187274240	jessica.wilson88@yahoo.com	0490	206834	307-722-414 65	85 Oak Ave, Rostov-on-Don, Russia	2025-11-18 20:47:11.711173+03
85	Jennifer	Miller	1961-07-13	F	+73503592987	jennifer.miller680@hotmail.com	4983	396615	299-104-677 21	183 Maple Dr, Kazan, Russia	2025-11-18 20:47:11.711173+03
86	David	Smith	2000-04-13	M	+77802187405	david.smith720@outlook.com	4130	064955	489-244-312 89	121 Birch St, Samara, Russia	2025-11-18 20:47:11.711173+03
87	Patricia	Smith	1992-09-13	M	+77039345736	patricia.smith69@outlook.com	1625	636661	300-568-022 25	21 Aspen St, Samara, Russia	2025-11-18 20:47:11.711173+03
88	Sarah	Wilson	2003-09-22	M	+70247145778	sarah.wilson737@hotmail.com	8321	396552	116-477-928 99	42 Willow Rd, Kazan, Russia	2025-11-18 20:47:11.711173+03
89	Jessica	Williams	1983-12-01	F	+71691927564	jessica.williams29@yahoo.com	8764	681180	266-788-555 09	156 Oak Ave, Saint Petersburg, Russia	2025-11-18 20:47:11.711173+03
90	Patricia	Thomas	2000-06-06	M	+71965246261	patricia.thomas906@yahoo.com	0320	387185	325-823-636 23	22 Aspen St, Omsk, Russia	2025-11-18 20:47:11.711173+03
91	Thomas	Jones	1967-10-15	F	+76582721929	thomas.jones227@outlook.com	1582	658866	366-893-769 67	163 Willow Rd, Yekaterinburg, Russia	2025-11-18 20:47:11.711173+03
92	Jennifer	Garcia	1978-02-27	F	+70418470572	jennifer.garcia677@hotmail.com	7103	510938	539-744-685 35	190 Cedar Ln, Samara, Russia	2025-11-18 20:47:11.711173+03
93	Jennifer	Martin	1963-10-14	F	+71205758505	jennifer.martin612@outlook.com	9669	896843	550-420-498 63	160 Cedar Ln, Saint Petersburg, Russia	2025-11-18 20:47:11.711173+03
94	Richard	Wilson	1964-11-06	M	+73823618160	richard.wilson529@outlook.com	7389	076084	573-201-279 66	53 Spruce Way, Samara, Russia	2025-11-18 20:47:11.711173+03
95	James	Brown	1989-05-01	F	+76455185451	james.brown264@gmail.com	4581	386094	316-092-596 64	48 Birch St, Yekaterinburg, Russia	2025-11-18 20:47:11.711173+03
96	Michael	Martin	1959-07-26	F	+74427287782	michael.martin688@gmail.com	4908	460236	723-521-308 75	180 Elm St, Nizhny Novgorod, Russia	2025-11-18 20:47:11.711173+03
97	Richard	Jackson	1938-10-18	M	+78291697213	richard.jackson237@yahoo.com	7846	464230	298-592-237 25	90 Willow Rd, Rostov-on-Don, Russia	2025-11-18 20:47:11.711173+03
98	Robert	Jones	1938-01-27	M	+74906858968	robert.jones387@outlook.com	3094	065250	442-894-721 12	142 Aspen St, Samara, Russia	2025-11-18 20:47:11.711173+03
99	Sarah	Davis	1996-09-25	M	+72026431156	sarah.davis108@hotmail.com	2172	413152	495-662-344 56	148 Pine Rd, Saint Petersburg, Russia	2025-11-18 20:47:11.711173+03
100	Jennifer	Moore	1957-11-21	M	+78453761730	jennifer.moore586@hotmail.com	9928	604348	421-906-880 01	172 Pine Rd, Novosibirsk, Russia	2025-11-18 20:47:11.711173+03
101	John	White	2005-12-29	M	+74831497488	john.white836@gmail.com	0541	751735	882-836-041 39	11 Willow Rd, Yekaterinburg, Russia	2025-11-18 20:47:11.711173+03
102	Karen	White	1972-11-28	M	+75037584677	karen.white156@yahoo.com	8941	247671	520-912-184 04	75 Birch St, Nizhny Novgorod, Russia	2025-11-18 20:47:11.711173+03
103	Charles	Jackson	2000-01-20	F	+74187017751	charles.jackson747@outlook.com	3478	057777	136-514-854 48	150 Birch St, Chelyabinsk, Russia	2025-11-18 20:47:11.711173+03
104	Jessica	Smith	1957-07-08	M	+73910994409	jessica.smith357@outlook.com	6234	487325	255-065-553 79	98 Spruce Way, Omsk, Russia	2025-11-18 20:47:11.711173+03
105	Karen	Thompson	1976-05-28	M	+72107843725	karen.thompson192@gmail.com	7857	703473	431-150-463 46	112 Pine Rd, Saint Petersburg, Russia	2025-11-18 20:47:11.711173+03
106	Charles	Wilson	1979-12-27	M	+77785437684	charles.wilson184@gmail.com	0584	455637	889-290-707 69	135 Birch St, Novosibirsk, Russia	2025-11-18 20:47:11.711173+03
107	John	Wilson	1968-06-09	F	+73719544892	john.wilson100@hotmail.com	4497	126002	780-492-828 27	146 Birch St, Omsk, Russia	2025-11-18 20:47:11.711173+03
108	Jessica	Thompson	1970-04-06	M	+70638282489	jessica.thompson940@hotmail.com	4390	410941	262-485-514 06	80 Oak Ave, Chelyabinsk, Russia	2025-11-18 20:47:11.711173+03
109	David	Thomas	1954-11-02	F	+70883309987	david.thomas197@yahoo.com	4015	915932	316-643-856 76	59 Maple Dr, Moscow, Russia	2025-11-18 20:47:11.711173+03
110	Joseph	Jones	1994-03-15	M	+72600029550	joseph.jones236@gmail.com	1909	814798	431-664-918 49	167 Pine Rd, Nizhny Novgorod, Russia	2025-11-18 20:47:11.711173+03
111	Patricia	Smith	1978-06-23	M	+71874107953	patricia.smith163@outlook.com	2771	431329	940-444-792 61	10 Maple Dr, Omsk, Russia	2025-11-18 20:47:11.711173+03
112	Michael	Martin	1964-11-07	M	+78780654072	michael.martin587@hotmail.com	7794	668784	409-231-623 30	116 Birch St, Yekaterinburg, Russia	2025-11-18 20:47:11.711173+03
113	John	Wilson	1961-02-18	F	+70039670016	john.wilson4@yahoo.com	0133	896797	630-797-285 67	173 Pine Rd, Chelyabinsk, Russia	2025-11-18 20:47:11.711173+03
114	Jessica	Anderson	1991-07-28	F	+77759597251	jessica.anderson718@gmail.com	7010	657161	248-799-516 02	72 Cedar Ln, Rostov-on-Don, Russia	2025-11-18 20:47:11.711173+03
115	Susan	Moore	1987-07-17	M	+74420824436	susan.moore293@yahoo.com	0597	625214	030-871-985 44	186 Birch St, Samara, Russia	2025-11-18 20:47:11.711173+03
116	Barbara	Thomas	2000-04-04	M	+74334500499	barbara.thomas635@hotmail.com	5475	448441	042-497-430 20	132 Main St, Moscow, Russia	2025-11-18 20:47:11.711173+03
117	Thomas	Williams	1985-12-13	M	+74256675809	thomas.williams128@gmail.com	1439	564064	217-392-393 97	164 Main St, Rostov-on-Don, Russia	2025-11-18 20:47:11.711173+03
118	Mary	Smith	1969-03-20	F	+78528955312	mary.smith904@yahoo.com	7729	494294	691-279-622 94	198 Maple Dr, Nizhny Novgorod, Russia	2025-11-18 20:47:11.711173+03
119	Thomas	Taylor	1974-08-13	M	+78010259487	thomas.taylor201@gmail.com	8532	700620	343-564-481 33	84 Willow Rd, Nizhny Novgorod, Russia	2025-11-18 20:47:11.711173+03
120	Karen	Rodriguez	1960-10-26	M	+77082673857	karen.rodriguez426@yahoo.com	0799	727886	171-927-355 04	36 Willow Rd, Moscow, Russia	2025-11-18 20:47:11.711173+03
\.


--
-- Data for Name: prescriptions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.prescriptions (prescription_id, visit_id, medication_name, duration_days, start_date, dose) FROM stdin;
1	1	Atorvastatin 20mg	30	2024-12-27	2
2	1	Amlodipine 5mg	15	2024-12-27	1
3	2	Levothyroxine 50mcg	16	2025-05-01	2
4	2	Calcium 600mg	27	2025-05-01	3
5	2	Salbutamol Inhaler	29	2025-05-01	1
6	2	Omeprazole 20mg	23	2025-05-01	3
7	3	Amoxicillin 250mg	8	2025-09-27	3
8	4	Aspirin 100mg	21	2025-03-18	2
9	4	Warfarin 5mg	9	2025-03-18	1
10	4	Ibuprofen 200mg	15	2025-03-18	1
11	4	Lisinopril 10mg	17	2025-03-18	1
12	5	Amoxicillin 500mg	18	2025-08-20	1
13	5	Levothyroxine 50mcg	11	2025-08-20	1
14	6	Calcium 600mg	28	2025-04-15	3
15	6	Diazepam 5mg	4	2025-04-15	3
16	6	Vitamin D3 2000IU	21	2025-04-15	2
17	6	Ibuprofen 400mg	5	2025-04-15	1
18	7	Warfarin 5mg	15	2025-03-07	3
20	7	Salbutamol Inhaler	15	2025-03-07	2
21	7	Levothyroxine 50mcg	15	2025-03-07	2
22	8	Amoxicillin 250mg	30	2025-07-02	1
24	9	Aspirin 100mg	26	2024-11-30	1
25	9	Amoxicillin 875mg	14	2024-11-30	3
26	10	Warfarin 5mg	26	2025-02-10	3
27	10	Calcium 600mg	20	2025-02-10	1
28	10	Vitamin D3 2000IU	27	2025-02-10	1
29	10	Ibuprofen 400mg	29	2025-02-10	2
30	11	Metoprolol 25mg	26	2025-08-08	2
31	12	Calcium 600mg	17	2025-01-10	1
32	12	Diazepam 5mg	10	2025-01-10	2
33	12	Amoxicillin 500mg	19	2025-01-10	3
34	12	Omeprazole 20mg	5	2025-01-10	1
35	13	Metoprolol 25mg	26	2025-05-03	2
36	14	Omeprazole 20mg	14	2025-11-05	2
37	14	Amoxicillin 875mg	16	2025-11-05	3
38	14	Ibuprofen 200mg	25	2025-11-05	1
39	14	Atorvastatin 20mg	27	2025-11-05	1
40	15	Amoxicillin 250mg	24	2025-08-19	3
41	15	Paracetamol 500mg	27	2025-08-19	1
42	15	Levothyroxine 50mcg	28	2025-08-19	2
43	15	Metoprolol 25mg	26	2025-08-19	3
44	16	Amoxicillin 875mg	17	2025-06-04	3
45	17	Cetirizine 10mg	26	2025-02-27	2
46	17	Metformin 500mg	15	2025-02-27	2
47	17	Metoprolol 25mg	13	2025-02-27	2
48	18	Aspirin 100mg	12	2025-10-02	3
49	18	Lisinopril 10mg	22	2025-10-02	3
50	18	Metformin 500mg	30	2025-10-02	2
51	19	Amoxicillin 875mg	3	2025-08-06	1
52	19	Metformin 500mg	21	2025-08-06	2
54	19	Omeprazole 20mg	22	2025-08-06	1
55	20	Ibuprofen 200mg	27	2025-10-25	2
56	20	Levothyroxine 50mcg	3	2025-10-25	1
57	20	Amoxicillin 500mg	24	2025-10-25	3
58	21	Amoxicillin 250mg	17	2024-12-02	1
59	22	Levothyroxine 50mcg	19	2024-12-16	1
60	22	Metoprolol 25mg	14	2024-12-16	3
62	22	Metformin 500mg	7	2024-12-16	3
63	23	Ibuprofen 400mg	24	2025-02-05	1
64	23	Salbutamol Inhaler	10	2025-02-05	2
65	23	Levothyroxine 50mcg	4	2025-02-05	2
66	23	Amlodipine 5mg	19	2025-02-05	1
67	25	Paracetamol 500mg	19	2025-06-08	3
68	25	Salbutamol Inhaler	17	2025-06-08	2
69	25	Amlodipine 5mg	6	2025-06-08	1
70	26	Amoxicillin 250mg	19	2025-03-09	2
71	26	Levothyroxine 50mcg	13	2025-03-09	3
72	26	Omeprazole 20mg	6	2025-03-09	3
73	27	Calcium 600mg	15	2025-06-03	2
74	27	Vitamin D3 2000IU	28	2025-06-03	2
75	27	Lisinopril 10mg	19	2025-06-03	3
76	31	Warfarin 5mg	16	2024-12-06	2
77	31	Cetirizine 10mg	7	2024-12-06	1
78	31	Amoxicillin 875mg	29	2024-12-06	2
79	32	Paracetamol 500mg	12	2025-11-02	1
80	32	Amoxicillin 875mg	6	2025-11-02	3
81	33	Diazepam 5mg	8	2025-07-14	2
82	33	Levothyroxine 50mcg	7	2025-07-14	3
83	34	Omeprazole 20mg	27	2024-11-28	2
84	34	Calcium 600mg	8	2024-11-28	2
85	34	Diazepam 5mg	28	2024-11-28	3
86	35	Levothyroxine 50mcg	28	2025-04-08	2
87	36	Atorvastatin 20mg	25	2025-06-21	2
89	37	Cetirizine 10mg	3	2025-06-18	3
90	37	Amoxicillin 250mg	29	2025-06-18	3
91	37	Levothyroxine 50mcg	26	2025-06-18	2
92	38	Vitamin D3 2000IU	30	2025-10-22	3
93	38	Amoxicillin 875mg	11	2025-10-22	3
94	38	Lisinopril 10mg	4	2025-10-22	2
96	39	Amoxicillin 500mg	11	2025-05-06	3
97	40	Amlodipine 5mg	3	2025-04-01	3
98	40	Amoxicillin 875mg	22	2025-04-01	1
99	41	Atorvastatin 20mg	29	2025-04-16	2
100	41	Salbutamol Inhaler	14	2025-04-16	1
101	41	Cetirizine 10mg	11	2025-04-16	2
103	42	Lisinopril 10mg	18	2025-08-18	1
104	43	Calcium 600mg	29	2025-08-10	2
105	43	Aspirin 100mg	16	2025-08-10	3
106	43	Amlodipine 5mg	22	2025-08-10	3
107	44	Metformin 500mg	11	2025-03-26	1
108	45	Diazepam 5mg	11	2025-04-30	3
109	45	Amoxicillin 250mg	24	2025-04-30	3
110	45	Paracetamol 500mg	28	2025-04-30	3
111	45	Ibuprofen 400mg	3	2025-04-30	1
112	46	Cetirizine 10mg	27	2025-08-16	3
113	47	Vitamin D3 2000IU	21	2025-05-19	1
115	48	Levothyroxine 50mcg	25	2025-05-14	3
116	48	Metformin 500mg	25	2025-05-14	2
117	48	Metoprolol 25mg	28	2025-05-14	3
118	49	Vitamin D3 2000IU	15	2025-10-17	1
119	51	Lisinopril 10mg	8	2024-12-23	2
120	52	Amlodipine 5mg	13	2025-04-24	3
121	52	Atorvastatin 20mg	7	2025-04-24	1
122	54	Calcium 600mg	20	2025-07-21	2
123	54	Ibuprofen 400mg	17	2025-07-21	1
124	54	Diazepam 5mg	5	2025-07-21	2
125	54	Amoxicillin 250mg	25	2025-07-21	3
126	55	Vitamin D3 2000IU	4	2025-07-13	3
127	55	Amoxicillin 250mg	11	2025-07-13	1
129	55	Amoxicillin 875mg	8	2025-07-13	2
130	57	Omeprazole 20mg	29	2025-08-12	1
131	58	Omeprazole 20mg	7	2025-01-17	1
132	58	Warfarin 5mg	28	2025-01-17	3
133	60	Atorvastatin 20mg	6	2025-11-14	1
134	60	Aspirin 100mg	12	2025-11-14	1
135	61	Vitamin D3 2000IU	15	2025-10-30	2
136	61	Calcium 600mg	17	2025-10-30	2
137	61	Amoxicillin 250mg	13	2025-10-30	2
138	63	Omeprazole 20mg	14	2024-12-03	2
139	63	Cetirizine 10mg	22	2024-12-03	2
140	63	Diazepam 5mg	21	2024-12-03	1
141	64	Diazepam 5mg	13	2025-06-10	1
142	65	Calcium 600mg	11	2024-12-20	2
143	67	Cetirizine 10mg	6	2025-08-28	1
144	67	Ibuprofen 400mg	5	2025-08-28	2
145	68	Ibuprofen 200mg	28	2025-09-17	1
146	68	Cetirizine 10mg	20	2025-09-17	1
147	69	Amoxicillin 500mg	5	2025-01-14	3
148	70	Calcium 600mg	9	2025-05-23	2
149	70	Amlodipine 5mg	13	2025-05-23	1
150	70	Salbutamol Inhaler	3	2025-05-23	1
151	72	Metoprolol 25mg	5	2025-03-17	2
152	72	Amoxicillin 250mg	23	2025-03-17	1
154	73	Diazepam 5mg	6	2024-12-16	3
155	74	Metformin 500mg	22	2025-06-17	2
156	76	Omeprazole 20mg	13	2025-03-16	2
157	76	Calcium 600mg	6	2025-03-16	3
158	76	Amlodipine 5mg	7	2025-03-16	1
159	76	Lisinopril 10mg	30	2025-03-16	1
160	77	Calcium 600mg	29	2025-09-07	2
161	77	Aspirin 100mg	8	2025-09-07	1
162	77	Cetirizine 10mg	9	2025-09-07	2
163	78	Ibuprofen 400mg	12	2025-01-31	1
164	78	Aspirin 100mg	19	2025-01-31	3
165	78	Atorvastatin 20mg	4	2025-01-31	3
166	78	Amoxicillin 500mg	15	2025-01-31	2
167	79	Salbutamol Inhaler	27	2025-08-16	2
168	79	Amlodipine 5mg	22	2025-08-16	1
169	79	Paracetamol 500mg	18	2025-08-16	3
170	79	Vitamin D3 2000IU	9	2025-08-16	2
171	80	Salbutamol Inhaler	15	2025-08-17	3
172	80	Warfarin 5mg	8	2025-08-17	1
173	82	Salbutamol Inhaler	13	2025-02-16	1
174	82	Amlodipine 5mg	19	2025-02-16	1
175	82	Paracetamol 500mg	25	2025-02-16	3
176	83	Metoprolol 25mg	25	2025-01-22	3
177	83	Paracetamol 500mg	29	2025-01-22	1
178	85	Salbutamol Inhaler	21	2025-02-14	3
179	86	Paracetamol 500mg	27	2025-01-08	2
180	87	Atorvastatin 20mg	24	2025-01-21	2
181	87	Amoxicillin 500mg	21	2025-01-21	1
182	88	Warfarin 5mg	23	2025-05-17	3
183	89	Paracetamol 500mg	8	2025-08-11	1
184	89	Calcium 600mg	5	2025-08-11	2
185	89	Omeprazole 20mg	7	2025-08-11	3
186	89	Metoprolol 25mg	22	2025-08-11	1
187	90	Amlodipine 5mg	18	2025-09-01	3
188	91	Vitamin D3 2000IU	20	2025-04-28	2
189	92	Paracetamol 500mg	28	2025-03-10	1
190	92	Lisinopril 10mg	29	2025-03-10	1
192	92	Warfarin 5mg	27	2025-03-10	2
193	93	Ibuprofen 200mg	18	2025-03-26	1
194	93	Ibuprofen 400mg	30	2025-03-26	1
195	93	Diazepam 5mg	24	2025-03-26	3
196	93	Warfarin 5mg	10	2025-03-26	3
197	94	Metformin 500mg	28	2025-08-12	2
198	94	Atorvastatin 20mg	13	2025-08-12	1
199	94	Aspirin 100mg	28	2025-08-12	3
200	94	Cetirizine 10mg	12	2025-08-12	3
201	95	Metformin 500mg	19	2025-09-13	3
202	95	Atorvastatin 20mg	12	2025-09-13	3
203	95	Cetirizine 10mg	20	2025-09-13	2
204	96	Ibuprofen 400mg	3	2025-10-11	2
206	97	Amoxicillin 875mg	29	2025-02-10	1
207	97	Metoprolol 25mg	3	2025-02-10	2
208	98	Aspirin 100mg	10	2024-12-23	3
209	99	Amoxicillin 500mg	13	2025-04-09	2
210	99	Salbutamol Inhaler	7	2025-04-09	2
212	101	Amoxicillin 500mg	3	2025-09-12	2
213	102	Amlodipine 5mg	7	2025-01-23	1
214	102	Ibuprofen 400mg	15	2025-01-23	1
215	103	Calcium 600mg	14	2025-03-01	2
216	103	Amoxicillin 250mg	7	2025-03-01	2
217	104	Warfarin 5mg	22	2024-11-30	3
218	106	Calcium 600mg	15	2025-08-08	3
219	106	Warfarin 5mg	22	2025-08-08	1
220	106	Amoxicillin 500mg	28	2025-08-08	2
221	107	Lisinopril 10mg	19	2025-01-07	1
222	108	Amoxicillin 500mg	21	2025-08-26	1
223	108	Paracetamol 500mg	21	2025-08-26	3
224	110	Lisinopril 10mg	23	2025-01-03	3
225	111	Amoxicillin 500mg	4	2025-09-04	3
226	113	Calcium 600mg	8	2025-06-11	1
227	114	Aspirin 100mg	5	2024-11-21	2
228	114	Metformin 500mg	28	2024-11-21	2
229	114	Warfarin 5mg	18	2024-11-21	3
230	114	Amoxicillin 875mg	9	2024-11-21	1
231	115	Amoxicillin 500mg	8	2025-09-25	1
232	115	Warfarin 5mg	29	2025-09-25	3
233	115	Paracetamol 500mg	24	2025-09-25	2
234	116	Paracetamol 500mg	18	2025-03-03	2
235	116	Amoxicillin 250mg	16	2025-03-03	2
236	116	Salbutamol Inhaler	7	2025-03-03	1
237	116	Levothyroxine 50mcg	21	2025-03-03	2
238	117	Ibuprofen 400mg	3	2025-05-08	1
239	118	Ibuprofen 400mg	19	2025-04-10	1
240	118	Lisinopril 10mg	10	2025-04-10	2
241	118	Omeprazole 20mg	10	2025-04-10	2
242	120	Levothyroxine 50mcg	9	2025-03-18	2
243	120	Vitamin D3 2000IU	3	2025-03-18	3
244	121	Atorvastatin 20mg	21	2025-08-20	3
245	121	Aspirin 100mg	28	2025-08-20	2
246	121	Amoxicillin 250mg	13	2025-08-20	2
247	122	Levothyroxine 50mcg	15	2025-07-08	3
248	122	Amoxicillin 875mg	13	2025-07-08	3
249	122	Amoxicillin 250mg	17	2025-07-08	2
250	124	Vitamin D3 2000IU	16	2025-08-27	2
251	124	Aspirin 100mg	16	2025-08-27	3
252	125	Lisinopril 10mg	8	2025-09-14	3
253	125	Paracetamol 500mg	17	2025-09-14	2
254	126	Omeprazole 20mg	29	2025-10-18	3
255	126	Amoxicillin 250mg	21	2025-10-18	3
257	130	Amlodipine 5mg	20	2025-08-08	2
258	130	Amoxicillin 250mg	30	2025-08-08	3
259	130	Omeprazole 20mg	7	2025-08-08	3
260	131	Lisinopril 10mg	3	2025-04-19	3
261	131	Ibuprofen 400mg	17	2025-04-19	1
262	131	Levothyroxine 50mcg	4	2025-04-19	3
263	131	Ibuprofen 200mg	12	2025-04-19	1
264	132	Cetirizine 10mg	17	2025-06-30	2
265	132	Ibuprofen 200mg	28	2025-06-30	2
266	133	Omeprazole 20mg	10	2024-12-28	3
267	133	Diazepam 5mg	19	2024-12-28	3
268	133	Metformin 500mg	24	2024-12-28	2
269	133	Ibuprofen 200mg	3	2024-12-28	3
270	134	Amoxicillin 875mg	17	2025-04-02	2
271	134	Aspirin 100mg	26	2025-04-02	2
272	134	Calcium 600mg	11	2025-04-02	3
273	135	Amlodipine 5mg	3	2025-09-29	2
274	135	Ibuprofen 200mg	23	2025-09-29	1
275	135	Ibuprofen 400mg	22	2025-09-29	3
276	136	Metformin 500mg	13	2025-07-03	2
277	137	Ibuprofen 200mg	6	2024-11-28	2
278	137	Aspirin 100mg	18	2024-11-28	2
279	138	Warfarin 5mg	6	2025-06-25	1
280	138	Salbutamol Inhaler	9	2025-06-25	2
281	138	Levothyroxine 50mcg	14	2025-06-25	3
282	139	Ibuprofen 200mg	11	2025-09-15	2
283	139	Amoxicillin 875mg	16	2025-09-15	1
284	139	Metoprolol 25mg	3	2025-09-15	3
285	139	Atorvastatin 20mg	12	2025-09-15	3
286	140	Salbutamol Inhaler	14	2025-07-31	2
289	140	Amoxicillin 250mg	4	2025-07-31	2
290	141	Metoprolol 25mg	22	2025-08-05	3
291	142	Cetirizine 10mg	21	2025-03-01	1
292	143	Metoprolol 25mg	23	2024-12-18	3
293	143	Metformin 500mg	18	2024-12-18	1
294	143	Atorvastatin 20mg	13	2024-12-18	2
295	144	Ibuprofen 200mg	5	2025-09-12	1
296	147	Calcium 600mg	17	2025-01-14	2
298	147	Warfarin 5mg	14	2025-01-14	3
299	147	Metformin 500mg	15	2025-01-14	3
300	148	Calcium 600mg	12	2025-01-09	1
301	148	Warfarin 5mg	12	2025-01-09	2
302	149	Vitamin D3 2000IU	14	2025-04-20	1
303	149	Metoprolol 25mg	18	2025-04-20	1
304	149	Metformin 500mg	21	2025-04-20	1
305	150	Aspirin 100mg	5	2025-04-02	1
306	150	Paracetamol 500mg	18	2025-04-02	2
307	151	Calcium 600mg	6	2025-06-08	3
308	152	Warfarin 5mg	11	2024-12-03	3
309	153	Warfarin 5mg	18	2025-02-07	3
310	153	Amoxicillin 250mg	5	2025-02-07	2
312	153	Salbutamol Inhaler	14	2025-02-07	3
313	155	Metformin 500mg	12	2025-10-11	2
314	156	Omeprazole 20mg	15	2025-08-03	2
315	156	Warfarin 5mg	17	2025-08-03	3
316	156	Ibuprofen 200mg	17	2025-08-03	2
317	158	Amoxicillin 875mg	7	2025-01-19	2
318	158	Ibuprofen 200mg	17	2025-01-19	2
319	159	Ibuprofen 200mg	13	2025-08-08	3
320	159	Calcium 600mg	23	2025-08-08	3
321	159	Amlodipine 5mg	23	2025-08-08	1
322	162	Omeprazole 20mg	29	2025-03-28	1
323	163	Metoprolol 25mg	18	2024-11-19	2
324	163	Lisinopril 10mg	29	2024-11-19	1
325	163	Calcium 600mg	10	2024-11-19	2
326	164	Amoxicillin 500mg	17	2025-09-18	1
327	164	Paracetamol 500mg	23	2025-09-18	1
328	164	Vitamin D3 2000IU	26	2025-09-18	1
329	164	Calcium 600mg	11	2025-09-18	3
330	165	Ibuprofen 400mg	30	2024-11-23	1
331	168	Paracetamol 500mg	19	2025-07-11	1
332	168	Amoxicillin 875mg	20	2025-07-11	2
333	170	Amoxicillin 500mg	28	2025-01-27	3
334	170	Diazepam 5mg	11	2025-01-27	2
336	171	Levothyroxine 50mcg	24	2025-08-02	3
337	172	Salbutamol Inhaler	11	2024-12-18	3
338	172	Vitamin D3 2000IU	12	2024-12-18	3
340	172	Cetirizine 10mg	15	2024-12-18	2
341	173	Ibuprofen 200mg	4	2025-10-24	2
342	176	Diazepam 5mg	30	2025-03-13	3
343	178	Salbutamol Inhaler	20	2025-02-24	3
344	178	Warfarin 5mg	22	2025-02-24	2
345	179	Lisinopril 10mg	27	2024-12-29	3
346	179	Amoxicillin 500mg	21	2024-12-29	2
347	179	Cetirizine 10mg	6	2024-12-29	1
348	180	Omeprazole 20mg	15	2025-02-20	3
349	180	Amoxicillin 500mg	29	2025-02-20	3
350	181	Salbutamol Inhaler	22	2025-08-27	3
351	182	Cetirizine 10mg	8	2025-10-10	3
352	182	Levothyroxine 50mcg	24	2025-10-10	3
353	182	Calcium 600mg	27	2025-10-10	2
354	183	Lisinopril 10mg	8	2025-06-11	1
355	183	Omeprazole 20mg	15	2025-06-11	2
356	183	Paracetamol 500mg	5	2025-06-11	2
357	184	Lisinopril 10mg	18	2025-05-05	1
358	184	Ibuprofen 400mg	14	2025-05-05	2
360	185	Calcium 600mg	4	2024-11-21	2
361	185	Amlodipine 5mg	22	2024-11-21	3
362	185	Amoxicillin 875mg	9	2024-11-21	3
363	185	Cetirizine 10mg	7	2024-11-21	3
364	186	Ibuprofen 400mg	10	2025-01-08	1
365	186	Amlodipine 5mg	8	2025-01-08	3
366	186	Amoxicillin 250mg	22	2025-01-08	2
367	187	Diazepam 5mg	5	2025-10-09	2
368	187	Aspirin 100mg	7	2025-10-09	3
369	187	Amlodipine 5mg	27	2025-10-09	3
370	188	Metformin 500mg	25	2025-09-21	2
371	188	Calcium 600mg	3	2025-09-21	1
372	188	Salbutamol Inhaler	29	2025-09-21	3
373	188	Paracetamol 500mg	11	2025-09-21	3
374	189	Metformin 500mg	20	2025-10-07	2
375	190	Amoxicillin 500mg	27	2025-08-04	1
376	190	Calcium 600mg	10	2025-08-04	3
377	190	Cetirizine 10mg	7	2025-08-04	2
378	193	Ibuprofen 400mg	11	2025-03-08	1
379	194	Levothyroxine 50mcg	14	2025-04-25	3
380	194	Ibuprofen 400mg	13	2025-04-25	1
381	194	Metformin 500mg	23	2025-04-25	1
382	195	Lisinopril 10mg	10	2025-02-22	3
383	196	Amoxicillin 250mg	25	2025-01-17	3
384	196	Amoxicillin 500mg	24	2025-01-17	3
385	196	Diazepam 5mg	7	2025-01-17	2
386	197	Metoprolol 25mg	25	2025-10-18	3
387	198	Warfarin 5mg	5	2025-04-28	3
388	198	Amoxicillin 250mg	23	2025-04-28	2
390	198	Metformin 500mg	28	2025-04-28	2
391	199	Cetirizine 10mg	6	2025-05-21	1
392	199	Amoxicillin 875mg	8	2025-05-21	1
393	199	Ibuprofen 400mg	7	2025-05-21	1
394	200	Amoxicillin 500mg	14	2025-04-14	2
395	200	Amlodipine 5mg	26	2025-04-14	2
396	200	Metformin 500mg	7	2025-04-14	1
397	200	Ibuprofen 200mg	27	2025-04-14	2
398	201	Vitamin D3 2000IU	25	2025-11-02	2
399	203	Aspirin 100mg	27	2025-09-07	1
400	203	Warfarin 5mg	3	2025-09-07	3
401	203	Paracetamol 500mg	15	2025-09-07	2
402	203	Metoprolol 25mg	20	2025-09-07	1
403	205	Salbutamol Inhaler	26	2025-02-06	3
404	206	Warfarin 5mg	28	2025-05-31	2
405	206	Cetirizine 10mg	20	2025-05-31	1
406	207	Salbutamol Inhaler	5	2025-04-29	1
407	207	Paracetamol 500mg	20	2025-04-29	1
408	207	Amlodipine 5mg	4	2025-04-29	2
409	207	Vitamin D3 2000IU	12	2025-04-29	1
410	209	Calcium 600mg	20	2025-10-09	2
411	209	Amlodipine 5mg	16	2025-10-09	1
412	209	Metoprolol 25mg	17	2025-10-09	1
413	209	Ibuprofen 400mg	11	2025-10-09	3
414	211	Amlodipine 5mg	20	2025-07-14	2
415	211	Levothyroxine 50mcg	15	2025-07-14	1
416	211	Cetirizine 10mg	4	2025-07-14	1
417	211	Amoxicillin 250mg	26	2025-07-14	2
418	212	Lisinopril 10mg	7	2025-08-02	1
419	212	Paracetamol 500mg	4	2025-08-02	2
420	213	Amlodipine 5mg	19	2025-08-23	2
421	213	Metoprolol 25mg	7	2025-08-23	2
422	213	Ibuprofen 200mg	20	2025-08-23	2
423	213	Omeprazole 20mg	19	2025-08-23	3
424	214	Amoxicillin 875mg	11	2025-01-12	2
425	214	Levothyroxine 50mcg	28	2025-01-12	2
426	214	Amoxicillin 250mg	7	2025-01-12	1
427	215	Cetirizine 10mg	18	2025-10-07	3
428	215	Amoxicillin 875mg	26	2025-10-07	3
429	215	Aspirin 100mg	18	2025-10-07	2
430	216	Vitamin D3 2000IU	30	2025-02-26	2
431	216	Paracetamol 500mg	20	2025-02-26	3
432	217	Salbutamol Inhaler	20	2025-08-13	3
433	217	Amoxicillin 250mg	26	2025-08-13	3
435	217	Amlodipine 5mg	3	2025-08-13	2
436	218	Omeprazole 20mg	10	2025-05-31	1
437	218	Warfarin 5mg	4	2025-05-31	3
438	219	Vitamin D3 2000IU	28	2025-05-11	2
439	220	Salbutamol Inhaler	25	2025-06-16	3
440	220	Metformin 500mg	13	2025-06-16	1
441	220	Cetirizine 10mg	21	2025-06-16	1
442	220	Vitamin D3 2000IU	7	2025-06-16	1
443	221	Amoxicillin 875mg	15	2025-09-26	3
444	221	Amoxicillin 250mg	29	2025-09-26	1
445	222	Salbutamol Inhaler	22	2025-03-11	2
446	222	Paracetamol 500mg	9	2025-03-11	2
447	223	Aspirin 100mg	9	2025-03-19	3
448	225	Aspirin 100mg	15	2025-01-07	3
449	225	Amlodipine 5mg	26	2025-01-07	3
450	226	Warfarin 5mg	4	2025-11-02	1
451	226	Ibuprofen 200mg	14	2025-11-02	1
452	226	Omeprazole 20mg	6	2025-11-02	1
454	227	Metformin 500mg	10	2025-01-24	2
455	228	Metformin 500mg	4	2025-02-16	3
456	229	Atorvastatin 20mg	16	2025-11-15	1
457	229	Calcium 600mg	6	2025-11-15	2
458	229	Metoprolol 25mg	22	2025-11-15	3
459	229	Omeprazole 20mg	24	2025-11-15	3
460	231	Paracetamol 500mg	16	2025-04-18	1
461	231	Salbutamol Inhaler	3	2025-04-18	2
463	232	Lisinopril 10mg	21	2025-07-23	2
464	232	Omeprazole 20mg	14	2025-07-23	1
465	232	Amoxicillin 500mg	25	2025-07-23	3
466	232	Paracetamol 500mg	13	2025-07-23	3
467	233	Warfarin 5mg	3	2025-08-27	3
468	233	Diazepam 5mg	10	2025-08-27	2
469	233	Aspirin 100mg	16	2025-08-27	1
470	234	Vitamin D3 2000IU	21	2025-03-29	1
471	234	Amoxicillin 500mg	30	2025-03-29	2
472	234	Lisinopril 10mg	17	2025-03-29	1
473	234	Ibuprofen 200mg	16	2025-03-29	3
474	235	Vitamin D3 2000IU	30	2025-09-18	3
475	235	Paracetamol 500mg	10	2025-09-18	1
476	235	Salbutamol Inhaler	9	2025-09-18	3
477	236	Atorvastatin 20mg	5	2025-05-10	3
478	237	Levothyroxine 50mcg	15	2025-08-19	1
479	237	Amoxicillin 250mg	7	2025-08-19	1
480	238	Aspirin 100mg	6	2025-07-28	2
481	238	Calcium 600mg	22	2025-07-28	2
482	238	Salbutamol Inhaler	15	2025-07-28	2
483	239	Calcium 600mg	10	2024-11-22	1
484	239	Amoxicillin 875mg	29	2024-11-22	3
485	239	Amlodipine 5mg	3	2024-11-22	3
486	239	Warfarin 5mg	14	2024-11-22	2
487	240	Lisinopril 10mg	10	2024-12-13	2
488	240	Calcium 600mg	24	2024-12-13	3
489	242	Ibuprofen 200mg	13	2025-03-25	2
490	242	Warfarin 5mg	3	2025-03-25	3
491	242	Amoxicillin 250mg	26	2025-03-25	3
492	242	Amoxicillin 875mg	11	2025-03-25	1
493	243	Cetirizine 10mg	20	2025-11-08	3
494	243	Metformin 500mg	20	2025-11-08	2
495	243	Omeprazole 20mg	25	2025-11-08	2
496	243	Amlodipine 5mg	3	2025-11-08	1
497	244	Aspirin 100mg	5	2025-06-10	1
498	244	Atorvastatin 20mg	18	2025-06-10	1
500	244	Calcium 600mg	17	2025-06-10	1
501	247	Amoxicillin 875mg	17	2025-04-25	1
502	247	Amoxicillin 500mg	6	2025-04-25	3
503	247	Metoprolol 25mg	23	2025-04-25	1
504	248	Atorvastatin 20mg	10	2025-04-13	3
505	248	Amoxicillin 250mg	20	2025-04-13	3
506	249	Amoxicillin 875mg	5	2025-02-05	1
507	251	Ibuprofen 400mg	21	2024-12-03	3
508	251	Levothyroxine 50mcg	28	2024-12-03	2
509	251	Omeprazole 20mg	6	2024-12-03	3
510	251	Cetirizine 10mg	17	2024-12-03	2
511	252	Amoxicillin 250mg	26	2025-06-08	3
512	253	Warfarin 5mg	16	2025-06-04	2
513	253	Cetirizine 10mg	24	2025-06-04	1
514	253	Atorvastatin 20mg	26	2025-06-04	2
515	253	Salbutamol Inhaler	18	2025-06-04	3
516	254	Diazepam 5mg	10	2025-01-13	1
517	255	Ibuprofen 200mg	22	2025-09-29	3
518	255	Calcium 600mg	8	2025-09-29	2
519	255	Salbutamol Inhaler	5	2025-09-29	3
520	255	Paracetamol 500mg	27	2025-09-29	2
521	256	Warfarin 5mg	16	2025-06-04	1
522	256	Amoxicillin 875mg	14	2025-06-04	2
523	256	Lisinopril 10mg	21	2025-06-04	2
524	256	Amoxicillin 250mg	19	2025-06-04	2
525	257	Cetirizine 10mg	26	2025-08-30	3
526	257	Salbutamol Inhaler	12	2025-08-30	1
527	258	Cetirizine 10mg	25	2025-03-21	1
528	258	Diazepam 5mg	7	2025-03-21	1
529	258	Amoxicillin 250mg	19	2025-03-21	2
530	258	Aspirin 100mg	15	2025-03-21	2
531	259	Paracetamol 500mg	25	2025-03-11	1
532	259	Amoxicillin 250mg	27	2025-03-11	2
533	260	Atorvastatin 20mg	8	2025-03-04	1
534	262	Amoxicillin 875mg	22	2025-02-28	3
535	264	Salbutamol Inhaler	24	2025-03-25	1
536	264	Ibuprofen 200mg	8	2025-03-25	2
537	264	Cetirizine 10mg	16	2025-03-25	2
538	265	Diazepam 5mg	23	2025-01-24	3
539	265	Ibuprofen 400mg	29	2025-01-24	2
540	265	Aspirin 100mg	25	2025-01-24	3
541	265	Omeprazole 20mg	18	2025-01-24	1
542	267	Amoxicillin 875mg	30	2025-04-10	2
543	267	Levothyroxine 50mcg	10	2025-04-10	2
544	267	Metoprolol 25mg	20	2025-04-10	1
545	268	Calcium 600mg	24	2024-12-05	2
546	268	Metformin 500mg	13	2024-12-05	1
547	269	Diazepam 5mg	28	2024-11-30	3
548	270	Atorvastatin 20mg	29	2025-01-12	1
549	271	Omeprazole 20mg	28	2025-08-21	3
550	271	Vitamin D3 2000IU	9	2025-08-21	1
551	271	Amoxicillin 250mg	19	2025-08-21	2
552	271	Amoxicillin 875mg	30	2025-08-21	2
553	272	Paracetamol 500mg	18	2025-08-18	3
554	272	Salbutamol Inhaler	26	2025-08-18	1
555	272	Diazepam 5mg	20	2025-08-18	3
556	272	Amlodipine 5mg	9	2025-08-18	2
557	273	Diazepam 5mg	6	2025-08-19	1
558	273	Amlodipine 5mg	21	2025-08-19	1
559	275	Ibuprofen 400mg	3	2025-01-20	3
560	275	Aspirin 100mg	10	2025-01-20	3
562	275	Vitamin D3 2000IU	30	2025-01-20	1
563	276	Ibuprofen 400mg	29	2025-09-13	3
564	276	Lisinopril 10mg	3	2025-09-13	2
565	276	Metformin 500mg	3	2025-09-13	1
566	276	Omeprazole 20mg	14	2025-09-13	1
567	277	Vitamin D3 2000IU	15	2025-08-27	1
569	278	Amlodipine 5mg	13	2025-08-11	2
570	278	Aspirin 100mg	22	2025-08-11	3
571	280	Aspirin 100mg	17	2025-08-13	3
572	281	Atorvastatin 20mg	10	2025-08-06	2
573	281	Cetirizine 10mg	10	2025-08-06	1
574	282	Cetirizine 10mg	12	2024-11-24	2
575	283	Warfarin 5mg	4	2024-12-07	2
576	283	Atorvastatin 20mg	15	2024-12-07	3
577	283	Calcium 600mg	20	2024-12-07	2
578	283	Ibuprofen 400mg	23	2024-12-07	3
579	284	Vitamin D3 2000IU	13	2024-12-03	1
580	285	Amoxicillin 500mg	18	2025-05-28	2
581	285	Amoxicillin 875mg	16	2025-05-28	2
582	285	Metformin 500mg	14	2025-05-28	1
583	285	Atorvastatin 20mg	21	2025-05-28	2
584	286	Warfarin 5mg	6	2024-11-21	2
585	286	Ibuprofen 400mg	11	2024-11-21	1
586	286	Metoprolol 25mg	29	2024-11-21	2
587	287	Amoxicillin 500mg	30	2025-04-16	2
588	288	Levothyroxine 50mcg	20	2025-01-10	3
589	288	Salbutamol Inhaler	15	2025-01-10	2
590	288	Lisinopril 10mg	6	2025-01-10	2
591	289	Atorvastatin 20mg	28	2025-05-08	1
592	289	Amoxicillin 250mg	8	2025-05-08	2
593	289	Levothyroxine 50mcg	23	2025-05-08	1
594	289	Salbutamol Inhaler	3	2025-05-08	2
595	290	Vitamin D3 2000IU	27	2025-01-25	2
596	290	Calcium 600mg	18	2025-01-25	1
597	292	Vitamin D3 2000IU	23	2025-01-24	1
598	293	Metformin 500mg	25	2025-03-02	1
600	293	Amoxicillin 250mg	25	2025-03-02	2
601	293	Calcium 600mg	23	2025-03-02	3
602	294	Metformin 500mg	18	2025-02-13	2
603	294	Diazepam 5mg	5	2025-02-13	3
604	295	Diazepam 5mg	22	2025-02-24	1
605	295	Levothyroxine 50mcg	11	2025-02-24	3
606	295	Metoprolol 25mg	8	2025-02-24	2
607	295	Ibuprofen 400mg	24	2025-02-24	2
608	296	Amoxicillin 500mg	23	2025-07-15	3
609	296	Aspirin 100mg	12	2025-07-15	1
610	297	Calcium 600mg	30	2025-08-29	1
611	297	Salbutamol Inhaler	20	2025-08-29	3
612	297	Ibuprofen 200mg	30	2025-08-29	2
613	298	Amoxicillin 500mg	16	2025-06-22	1
614	299	Cetirizine 10mg	29	2025-03-13	3
615	299	Amlodipine 5mg	21	2025-03-13	1
616	299	Atorvastatin 20mg	23	2025-03-13	2
617	300	Metoprolol 25mg	13	2025-02-14	1
618	300	Vitamin D3 2000IU	11	2025-02-14	1
619	300	Aspirin 100mg	7	2025-02-14	3
621	301	Amoxicillin 875mg	13	2025-06-26	2
623	303	Levothyroxine 50mcg	24	2025-11-01	2
624	303	Aspirin 100mg	27	2025-11-01	3
625	304	Metoprolol 25mg	28	2025-02-08	1
626	304	Metformin 500mg	5	2025-02-08	2
628	304	Ibuprofen 200mg	7	2025-02-08	2
629	305	Amoxicillin 250mg	12	2025-04-23	3
630	305	Amoxicillin 875mg	10	2025-04-23	2
631	307	Vitamin D3 2000IU	22	2025-11-08	1
632	307	Calcium 600mg	21	2025-11-08	2
633	308	Paracetamol 500mg	24	2025-10-02	3
634	308	Amlodipine 5mg	30	2025-10-02	1
635	308	Diazepam 5mg	6	2025-10-02	1
636	309	Vitamin D3 2000IU	9	2025-05-09	3
637	309	Salbutamol Inhaler	29	2025-05-09	3
638	310	Paracetamol 500mg	13	2025-09-04	1
639	311	Cetirizine 10mg	26	2025-10-15	3
640	313	Warfarin 5mg	30	2024-12-07	3
642	313	Amoxicillin 875mg	8	2024-12-07	1
643	314	Amoxicillin 500mg	27	2024-11-21	2
644	314	Warfarin 5mg	25	2024-11-21	1
645	314	Vitamin D3 2000IU	29	2024-11-21	3
647	315	Metformin 500mg	16	2025-04-12	3
648	315	Metoprolol 25mg	18	2025-04-12	3
649	316	Cetirizine 10mg	5	2025-03-01	1
650	316	Calcium 600mg	12	2025-03-01	3
651	317	Amoxicillin 250mg	26	2025-03-01	2
652	317	Omeprazole 20mg	29	2025-03-01	2
653	317	Levothyroxine 50mcg	17	2025-03-01	3
654	318	Ibuprofen 400mg	20	2024-12-26	3
655	318	Amoxicillin 875mg	24	2024-12-26	3
656	318	Metoprolol 25mg	9	2024-12-26	1
657	322	Lisinopril 10mg	11	2025-07-02	3
658	322	Calcium 600mg	20	2025-07-02	2
659	322	Atorvastatin 20mg	22	2025-07-02	2
660	323	Amoxicillin 875mg	9	2025-09-10	1
661	325	Metformin 500mg	16	2025-01-04	2
662	326	Salbutamol Inhaler	22	2025-02-28	3
663	326	Warfarin 5mg	30	2025-02-28	2
665	327	Omeprazole 20mg	29	2025-01-26	1
666	327	Amoxicillin 500mg	28	2025-01-26	2
667	327	Salbutamol Inhaler	22	2025-01-26	1
668	328	Paracetamol 500mg	17	2025-07-11	2
670	328	Vitamin D3 2000IU	23	2025-07-11	1
671	329	Aspirin 100mg	4	2025-02-03	2
672	329	Vitamin D3 2000IU	25	2025-02-03	3
673	329	Lisinopril 10mg	13	2025-02-03	3
674	330	Metoprolol 25mg	23	2025-04-28	3
675	330	Amoxicillin 250mg	4	2025-04-28	1
676	333	Salbutamol Inhaler	14	2025-10-30	2
677	333	Diazepam 5mg	5	2025-10-30	3
678	334	Aspirin 100mg	30	2025-08-04	1
679	334	Warfarin 5mg	23	2025-08-04	2
680	334	Atorvastatin 20mg	23	2025-08-04	2
681	335	Amlodipine 5mg	3	2025-10-20	2
682	336	Calcium 600mg	20	2025-07-07	3
683	336	Paracetamol 500mg	27	2025-07-07	3
684	337	Cetirizine 10mg	4	2025-05-14	2
685	337	Amoxicillin 500mg	25	2025-05-14	1
686	337	Warfarin 5mg	3	2025-05-14	2
687	337	Calcium 600mg	21	2025-05-14	3
688	339	Omeprazole 20mg	23	2024-12-14	3
690	341	Amoxicillin 500mg	6	2025-10-14	2
691	341	Atorvastatin 20mg	23	2025-10-14	2
692	341	Metoprolol 25mg	4	2025-10-14	1
693	341	Amoxicillin 875mg	9	2025-10-14	2
694	342	Levothyroxine 50mcg	9	2025-08-30	1
695	342	Ibuprofen 200mg	28	2025-08-30	2
696	343	Lisinopril 10mg	13	2025-01-12	3
697	343	Amlodipine 5mg	5	2025-01-12	2
698	344	Atorvastatin 20mg	5	2025-10-11	2
699	344	Warfarin 5mg	30	2025-10-11	3
700	345	Diazepam 5mg	25	2025-04-23	2
702	345	Atorvastatin 20mg	9	2025-04-23	3
703	345	Metoprolol 25mg	3	2025-04-23	2
704	346	Diazepam 5mg	6	2025-04-27	2
705	346	Calcium 600mg	6	2025-04-27	2
706	346	Lisinopril 10mg	20	2025-04-27	1
707	348	Ibuprofen 200mg	22	2025-08-20	2
708	349	Levothyroxine 50mcg	10	2025-07-30	3
711	350	Amoxicillin 500mg	9	2025-11-05	3
712	350	Lisinopril 10mg	5	2025-11-05	1
713	351	Amoxicillin 250mg	18	2025-10-06	2
714	351	Atorvastatin 20mg	26	2025-10-06	1
715	352	Ibuprofen 200mg	16	2025-06-16	1
716	352	Levothyroxine 50mcg	28	2025-06-16	3
717	354	Ibuprofen 200mg	4	2025-08-20	2
718	354	Lisinopril 10mg	18	2025-08-20	3
719	354	Ibuprofen 400mg	13	2025-08-20	1
720	354	Diazepam 5mg	8	2025-08-20	1
721	355	Salbutamol Inhaler	10	2024-12-25	3
722	355	Cetirizine 10mg	5	2024-12-25	3
723	355	Paracetamol 500mg	21	2024-12-25	1
724	355	Lisinopril 10mg	20	2024-12-25	2
725	356	Vitamin D3 2000IU	10	2025-09-10	3
726	357	Amlodipine 5mg	5	2025-06-16	1
727	358	Amlodipine 5mg	11	2025-07-07	1
728	358	Levothyroxine 50mcg	19	2025-07-07	2
730	359	Atorvastatin 20mg	16	2025-10-03	1
731	359	Cetirizine 10mg	10	2025-10-03	2
732	359	Ibuprofen 200mg	15	2025-10-03	1
734	361	Calcium 600mg	10	2025-05-11	3
735	362	Paracetamol 500mg	30	2025-11-09	2
736	362	Ibuprofen 200mg	9	2025-11-09	2
738	363	Warfarin 5mg	18	2025-04-09	1
739	364	Vitamin D3 2000IU	15	2025-09-21	3
740	364	Paracetamol 500mg	19	2025-09-21	1
741	365	Metformin 500mg	10	2025-02-05	3
742	365	Calcium 600mg	12	2025-02-05	1
743	366	Paracetamol 500mg	19	2025-02-02	2
744	368	Metoprolol 25mg	13	2025-09-05	3
745	369	Diazepam 5mg	15	2025-09-12	1
746	369	Amoxicillin 875mg	16	2025-09-12	1
747	369	Salbutamol Inhaler	27	2025-09-12	2
748	370	Metoprolol 25mg	14	2025-04-30	1
749	370	Amoxicillin 875mg	14	2025-04-30	2
750	371	Salbutamol Inhaler	21	2025-03-19	3
751	372	Levothyroxine 50mcg	17	2025-01-27	2
752	372	Amoxicillin 500mg	22	2025-01-27	1
753	375	Atorvastatin 20mg	26	2025-06-06	2
754	375	Lisinopril 10mg	17	2025-06-06	2
755	376	Paracetamol 500mg	30	2025-10-05	3
757	376	Ibuprofen 200mg	22	2025-10-05	2
758	376	Amlodipine 5mg	29	2025-10-05	1
759	377	Metformin 500mg	16	2024-12-02	1
760	377	Ibuprofen 200mg	9	2024-12-02	1
761	377	Levothyroxine 50mcg	13	2024-12-02	2
762	377	Vitamin D3 2000IU	9	2024-12-02	1
763	378	Diazepam 5mg	9	2025-08-09	3
764	378	Omeprazole 20mg	19	2025-08-09	2
766	380	Metformin 500mg	4	2024-12-18	2
767	381	Amlodipine 5mg	10	2025-05-24	2
768	381	Cetirizine 10mg	22	2025-05-24	2
769	382	Amlodipine 5mg	15	2025-11-09	3
770	383	Amoxicillin 500mg	9	2025-08-28	3
771	383	Atorvastatin 20mg	13	2025-08-28	2
772	383	Amoxicillin 250mg	16	2025-08-28	3
773	383	Calcium 600mg	18	2025-08-28	1
774	384	Atorvastatin 20mg	8	2024-12-04	3
775	384	Warfarin 5mg	18	2024-12-04	3
776	385	Aspirin 100mg	15	2025-07-14	3
777	385	Diazepam 5mg	14	2025-07-14	2
779	386	Metoprolol 25mg	9	2025-01-30	1
780	386	Warfarin 5mg	22	2025-01-30	2
781	386	Aspirin 100mg	16	2025-01-30	2
782	387	Calcium 600mg	21	2024-11-28	2
783	387	Amoxicillin 875mg	18	2024-11-28	2
784	387	Warfarin 5mg	20	2024-11-28	2
785	387	Amoxicillin 500mg	25	2024-11-28	1
786	388	Metoprolol 25mg	28	2025-10-13	1
787	388	Amoxicillin 500mg	30	2025-10-13	1
788	389	Salbutamol Inhaler	15	2025-09-30	2
789	390	Amoxicillin 500mg	16	2025-11-07	3
790	391	Calcium 600mg	29	2025-10-09	1
791	392	Warfarin 5mg	24	2025-08-11	1
792	393	Salbutamol Inhaler	23	2025-09-01	2
793	394	Amoxicillin 250mg	18	2025-07-21	2
794	394	Metoprolol 25mg	6	2025-07-21	3
795	394	Amlodipine 5mg	13	2025-07-21	3
796	395	Vitamin D3 2000IU	3	2025-09-14	3
797	396	Atorvastatin 20mg	15	2025-10-25	1
798	396	Amlodipine 5mg	29	2025-10-25	1
799	396	Ibuprofen 200mg	7	2025-10-25	3
800	396	Amoxicillin 875mg	30	2025-10-25	2
801	397	Lisinopril 10mg	18	2025-08-25	1
803	397	Omeprazole 20mg	28	2025-08-25	1
804	398	Amlodipine 5mg	30	2025-08-08	2
805	399	Warfarin 5mg	21	2024-12-18	1
806	399	Amoxicillin 875mg	6	2024-12-18	3
807	399	Amlodipine 5mg	28	2024-12-18	1
808	399	Ibuprofen 400mg	11	2024-12-18	2
809	401	Warfarin 5mg	25	2025-05-29	3
810	401	Amoxicillin 250mg	15	2025-05-29	3
811	401	Diazepam 5mg	27	2025-05-29	3
812	401	Metformin 500mg	3	2025-05-29	2
813	402	Warfarin 5mg	3	2025-05-28	3
814	404	Lisinopril 10mg	19	2025-09-08	3
815	405	Cetirizine 10mg	27	2025-07-26	1
816	405	Vitamin D3 2000IU	28	2025-07-26	3
817	406	Amlodipine 5mg	10	2025-11-04	3
818	406	Cetirizine 10mg	24	2025-11-04	1
819	407	Amoxicillin 500mg	9	2025-06-10	3
820	407	Vitamin D3 2000IU	30	2025-06-10	3
821	407	Omeprazole 20mg	18	2025-06-10	2
822	407	Metoprolol 25mg	27	2025-06-10	3
823	409	Atorvastatin 20mg	16	2025-03-24	1
824	410	Atorvastatin 20mg	10	2025-04-11	3
825	410	Ibuprofen 200mg	8	2025-04-11	1
826	410	Metformin 500mg	22	2025-04-11	1
827	411	Atorvastatin 20mg	18	2025-08-12	3
828	412	Lisinopril 10mg	15	2025-08-11	3
829	413	Warfarin 5mg	12	2024-11-19	2
830	413	Calcium 600mg	18	2024-11-19	2
831	413	Atorvastatin 20mg	15	2024-11-19	3
832	414	Amlodipine 5mg	14	2025-06-14	3
833	415	Metoprolol 25mg	14	2025-09-14	2
834	415	Amoxicillin 500mg	14	2025-09-14	2
835	416	Salbutamol Inhaler	25	2025-08-03	2
836	416	Warfarin 5mg	23	2025-08-03	3
837	418	Metoprolol 25mg	23	2024-12-10	3
838	418	Metformin 500mg	26	2024-12-10	3
839	419	Ibuprofen 400mg	14	2025-03-19	2
840	419	Omeprazole 20mg	12	2025-03-19	3
841	419	Salbutamol Inhaler	6	2025-03-19	2
842	420	Paracetamol 500mg	25	2025-05-20	3
843	421	Levothyroxine 50mcg	16	2025-09-05	2
844	421	Ibuprofen 400mg	21	2025-09-05	2
845	421	Amoxicillin 500mg	5	2025-09-05	1
846	421	Atorvastatin 20mg	30	2025-09-05	2
847	422	Levothyroxine 50mcg	26	2025-11-12	1
848	423	Levothyroxine 50mcg	18	2025-04-06	2
849	423	Paracetamol 500mg	11	2025-04-06	1
850	423	Calcium 600mg	11	2025-04-06	2
851	424	Diazepam 5mg	16	2025-10-10	2
852	425	Aspirin 100mg	3	2025-03-12	1
853	425	Amoxicillin 875mg	9	2025-03-12	1
854	426	Ibuprofen 400mg	4	2025-02-05	3
855	426	Amlodipine 5mg	9	2025-02-05	1
856	427	Atorvastatin 20mg	4	2025-01-30	2
857	427	Calcium 600mg	26	2025-01-30	1
860	428	Amoxicillin 250mg	30	2024-12-13	3
861	429	Amoxicillin 875mg	19	2025-10-18	3
862	429	Paracetamol 500mg	29	2025-10-18	1
863	429	Amlodipine 5mg	14	2025-10-18	1
864	429	Metoprolol 25mg	14	2025-10-18	1
865	430	Amoxicillin 250mg	14	2025-11-09	1
866	430	Warfarin 5mg	28	2025-11-09	2
868	431	Ibuprofen 400mg	10	2025-09-07	3
869	431	Metoprolol 25mg	11	2025-09-07	1
870	431	Amoxicillin 250mg	4	2025-09-07	3
871	432	Calcium 600mg	19	2025-07-10	1
872	432	Levothyroxine 50mcg	5	2025-07-10	3
873	433	Salbutamol Inhaler	11	2025-09-08	1
874	433	Amoxicillin 875mg	23	2025-09-08	2
876	434	Ibuprofen 400mg	26	2025-07-09	3
877	434	Salbutamol Inhaler	28	2025-07-09	2
878	434	Ibuprofen 200mg	18	2025-07-09	3
879	435	Metformin 500mg	12	2025-10-10	2
880	435	Vitamin D3 2000IU	23	2025-10-10	3
881	435	Calcium 600mg	25	2025-10-10	1
882	436	Amoxicillin 875mg	6	2025-01-31	3
883	436	Diazepam 5mg	8	2025-01-31	3
885	437	Calcium 600mg	3	2025-05-01	1
886	437	Ibuprofen 400mg	7	2025-05-01	2
887	439	Metoprolol 25mg	11	2025-02-13	3
888	440	Amlodipine 5mg	10	2025-02-04	3
889	441	Omeprazole 20mg	26	2025-04-13	3
890	441	Metoprolol 25mg	27	2025-04-13	1
891	441	Ibuprofen 200mg	16	2025-04-13	1
892	441	Lisinopril 10mg	3	2025-04-13	1
893	442	Amoxicillin 250mg	27	2025-01-08	3
894	442	Vitamin D3 2000IU	10	2025-01-08	3
895	442	Atorvastatin 20mg	21	2025-01-08	1
896	442	Metoprolol 25mg	6	2025-01-08	2
897	443	Metoprolol 25mg	8	2025-05-12	3
898	443	Warfarin 5mg	20	2025-05-12	2
899	443	Amlodipine 5mg	15	2025-05-12	2
900	443	Ibuprofen 400mg	18	2025-05-12	2
901	444	Diazepam 5mg	7	2025-10-07	3
902	444	Metoprolol 25mg	5	2025-10-07	2
903	444	Atorvastatin 20mg	3	2025-10-07	1
904	444	Paracetamol 500mg	25	2025-10-07	2
905	445	Ibuprofen 200mg	12	2025-04-11	2
907	445	Ibuprofen 400mg	14	2025-04-11	2
908	446	Lisinopril 10mg	26	2025-01-16	1
909	446	Levothyroxine 50mcg	6	2025-01-16	2
910	446	Paracetamol 500mg	23	2025-01-16	3
911	446	Diazepam 5mg	20	2025-01-16	1
912	447	Amlodipine 5mg	24	2025-03-25	2
913	447	Levothyroxine 50mcg	28	2025-03-25	2
914	448	Vitamin D3 2000IU	12	2025-10-24	3
915	448	Amoxicillin 875mg	9	2025-10-24	1
916	450	Amoxicillin 250mg	8	2024-12-24	1
917	450	Omeprazole 20mg	12	2024-12-24	1
918	451	Omeprazole 20mg	18	2025-04-17	1
919	452	Diazepam 5mg	19	2024-11-21	2
920	452	Salbutamol Inhaler	22	2024-11-21	2
921	456	Amoxicillin 500mg	17	2025-07-14	2
922	456	Amoxicillin 250mg	18	2025-07-14	1
923	457	Amoxicillin 250mg	27	2025-07-07	3
925	457	Aspirin 100mg	12	2025-07-07	1
926	457	Metoprolol 25mg	12	2025-07-07	1
927	458	Amlodipine 5mg	6	2025-11-14	1
928	458	Vitamin D3 2000IU	18	2025-11-14	3
929	458	Atorvastatin 20mg	9	2025-11-14	3
930	458	Warfarin 5mg	29	2025-11-14	3
931	459	Paracetamol 500mg	5	2025-04-24	3
932	459	Metformin 500mg	6	2025-04-24	2
933	460	Lisinopril 10mg	30	2025-03-09	2
934	460	Amoxicillin 250mg	27	2025-03-09	1
935	462	Omeprazole 20mg	21	2025-04-11	3
936	462	Paracetamol 500mg	17	2025-04-11	1
937	462	Amlodipine 5mg	21	2025-04-11	1
938	462	Metoprolol 25mg	25	2025-04-11	3
939	464	Metoprolol 25mg	27	2024-12-15	3
940	464	Ibuprofen 400mg	26	2024-12-15	3
941	464	Amoxicillin 500mg	22	2024-12-15	3
942	464	Salbutamol Inhaler	3	2024-12-15	1
943	465	Calcium 600mg	25	2025-01-01	1
944	465	Metformin 500mg	21	2025-01-01	2
945	466	Aspirin 100mg	18	2025-09-27	3
946	466	Ibuprofen 200mg	15	2025-09-27	2
947	466	Salbutamol Inhaler	4	2025-09-27	1
948	470	Amlodipine 5mg	9	2025-05-25	3
949	471	Metoprolol 25mg	15	2025-02-12	1
950	471	Amoxicillin 875mg	14	2025-02-12	1
951	473	Calcium 600mg	3	2025-01-14	1
952	473	Vitamin D3 2000IU	19	2025-01-14	2
953	473	Aspirin 100mg	26	2025-01-14	3
955	474	Amoxicillin 875mg	10	2024-12-11	2
957	476	Atorvastatin 20mg	18	2025-07-06	1
958	478	Metoprolol 25mg	4	2025-10-16	2
959	478	Amoxicillin 500mg	28	2025-10-16	2
960	479	Atorvastatin 20mg	20	2025-01-08	1
961	479	Warfarin 5mg	15	2025-01-08	2
963	479	Amoxicillin 875mg	25	2025-01-08	1
964	480	Diazepam 5mg	24	2025-03-10	1
965	480	Levothyroxine 50mcg	19	2025-03-10	2
966	480	Metoprolol 25mg	29	2025-03-10	1
967	480	Aspirin 100mg	25	2025-03-10	1
968	482	Atorvastatin 20mg	21	2024-12-09	1
969	482	Paracetamol 500mg	22	2024-12-09	3
970	482	Amoxicillin 250mg	14	2024-12-09	1
971	483	Ibuprofen 200mg	8	2025-07-28	3
972	483	Metoprolol 25mg	13	2025-07-28	2
973	483	Amoxicillin 875mg	22	2025-07-28	2
974	483	Amlodipine 5mg	24	2025-07-28	1
975	485	Amoxicillin 500mg	29	2025-05-08	1
976	485	Vitamin D3 2000IU	6	2025-05-08	2
977	485	Atorvastatin 20mg	9	2025-05-08	3
978	488	Amlodipine 5mg	24	2025-09-01	1
979	488	Warfarin 5mg	13	2025-09-01	1
980	489	Metformin 500mg	27	2025-09-27	1
981	489	Atorvastatin 20mg	24	2025-09-27	2
982	489	Warfarin 5mg	23	2025-09-27	1
983	490	Metformin 500mg	17	2025-04-12	3
984	490	Amlodipine 5mg	14	2025-04-12	3
985	490	Warfarin 5mg	30	2025-04-12	3
986	492	Lisinopril 10mg	26	2025-07-23	2
987	492	Ibuprofen 400mg	7	2025-07-23	3
988	492	Vitamin D3 2000IU	25	2025-07-23	2
989	492	Warfarin 5mg	3	2025-07-23	2
990	494	Calcium 600mg	25	2024-11-30	1
991	495	Paracetamol 500mg	10	2025-10-08	2
992	495	Aspirin 100mg	28	2025-10-08	3
993	496	Atorvastatin 20mg	26	2025-02-27	1
994	497	Metformin 500mg	15	2025-06-03	1
995	497	Levothyroxine 50mcg	23	2025-06-03	1
996	497	Lisinopril 10mg	20	2025-06-03	1
997	497	Amoxicillin 250mg	11	2025-06-03	3
998	498	Calcium 600mg	19	2025-04-02	3
999	500	Salbutamol Inhaler	24	2025-03-20	2
1000	500	Amoxicillin 250mg	29	2025-03-20	3
1001	500	Cetirizine 10mg	25	2025-03-20	2
1002	500	Paracetamol 500mg	10	2025-03-20	2
\.


--
-- Data for Name: specializations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.specializations (specialization_id, name, category) FROM stdin;
1	Cardiology	therapy
2	Neurology	therapy
3	Dermatology	therapy
4	Orthopedics	surgery
5	General Surgery	surgery
6	Ophthalmology	surgery
7	Radiology	diagnostics
8	Laboratory Diagnostics	diagnostics
9	Pediatrics	pediatrics
10	Family Medicine	therapy
\.


--
-- Data for Name: visit_diagnoses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.visit_diagnoses (visit_id, diagnosis_id, certainty_level) FROM stdin;
1	12	confirmed
1	42	confirmed
1	6	preliminary
2	19	suspected
2	39	suspected
2	42	preliminary
3	39	confirmed
3	24	suspected
4	30	suspected
5	19	confirmed
5	17	preliminary
6	6	suspected
6	24	suspected
6	13	suspected
7	36	confirmed
8	24	preliminary
8	6	confirmed
9	1	suspected
10	3	confirmed
11	10	suspected
12	16	confirmed
12	3	suspected
12	11	suspected
13	26	preliminary
13	8	confirmed
14	17	confirmed
14	27	confirmed
14	35	confirmed
15	30	suspected
16	2	confirmed
17	36	confirmed
17	15	suspected
17	14	suspected
18	21	confirmed
19	7	suspected
20	7	suspected
20	13	suspected
21	2	preliminary
21	37	confirmed
22	27	confirmed
22	26	preliminary
22	14	confirmed
23	12	preliminary
24	37	preliminary
24	12	preliminary
25	14	preliminary
25	26	confirmed
26	8	preliminary
27	1	preliminary
27	24	suspected
27	16	preliminary
28	36	confirmed
28	1	preliminary
28	2	preliminary
29	2	preliminary
29	4	suspected
30	15	suspected
30	20	preliminary
31	34	suspected
31	7	confirmed
32	5	confirmed
32	35	confirmed
33	36	preliminary
34	25	preliminary
35	40	confirmed
35	17	confirmed
35	15	confirmed
36	23	suspected
36	8	suspected
36	6	suspected
37	45	preliminary
37	4	preliminary
38	32	preliminary
39	22	confirmed
39	17	confirmed
40	44	suspected
41	40	preliminary
41	13	preliminary
42	38	confirmed
42	39	suspected
42	41	confirmed
43	26	confirmed
43	41	preliminary
43	32	suspected
44	38	preliminary
44	39	preliminary
44	31	suspected
45	36	confirmed
45	39	suspected
46	41	confirmed
46	7	suspected
47	45	confirmed
48	3	preliminary
49	32	preliminary
49	18	preliminary
50	25	confirmed
50	34	suspected
51	7	preliminary
52	44	preliminary
52	34	preliminary
52	37	preliminary
53	36	confirmed
54	41	confirmed
54	37	preliminary
54	21	preliminary
55	30	preliminary
56	34	preliminary
56	32	preliminary
56	39	suspected
57	40	confirmed
58	21	confirmed
58	7	suspected
59	16	suspected
59	24	preliminary
59	13	suspected
60	6	preliminary
60	27	preliminary
60	17	preliminary
61	2	confirmed
62	24	preliminary
62	41	preliminary
62	1	suspected
63	9	confirmed
63	45	confirmed
64	20	suspected
65	5	confirmed
66	9	preliminary
66	17	suspected
67	24	suspected
67	39	preliminary
68	9	confirmed
69	42	confirmed
70	14	confirmed
71	39	preliminary
71	6	preliminary
71	32	preliminary
72	36	suspected
72	2	preliminary
73	18	suspected
73	24	confirmed
74	11	confirmed
74	35	suspected
74	6	confirmed
75	32	confirmed
76	3	suspected
77	9	confirmed
78	22	suspected
78	26	confirmed
78	9	preliminary
79	6	confirmed
79	25	preliminary
79	44	preliminary
80	18	suspected
81	24	confirmed
81	6	confirmed
81	41	suspected
82	7	confirmed
82	26	suspected
83	29	preliminary
83	43	confirmed
84	8	preliminary
85	17	preliminary
85	34	preliminary
85	28	confirmed
86	37	confirmed
86	25	suspected
86	4	preliminary
87	30	confirmed
87	16	suspected
88	43	suspected
88	24	confirmed
89	17	preliminary
89	9	suspected
90	14	suspected
90	5	suspected
90	8	suspected
91	43	suspected
91	14	preliminary
92	27	confirmed
93	13	preliminary
94	45	confirmed
94	8	preliminary
95	14	suspected
95	39	confirmed
95	30	preliminary
96	33	preliminary
97	36	confirmed
97	43	suspected
98	45	preliminary
99	14	confirmed
100	9	preliminary
100	19	preliminary
100	43	preliminary
101	23	preliminary
101	22	confirmed
102	29	confirmed
102	39	suspected
103	16	confirmed
103	7	preliminary
103	5	preliminary
104	7	preliminary
104	23	suspected
104	36	confirmed
105	36	preliminary
106	36	suspected
106	27	suspected
106	32	preliminary
107	32	preliminary
108	13	confirmed
108	8	suspected
108	17	preliminary
109	26	suspected
109	23	confirmed
109	32	suspected
110	41	preliminary
111	28	suspected
111	10	suspected
111	16	confirmed
112	37	confirmed
113	6	confirmed
113	40	suspected
113	12	preliminary
114	44	suspected
115	44	confirmed
115	11	suspected
116	30	suspected
116	3	suspected
117	40	confirmed
117	11	preliminary
117	27	preliminary
118	2	confirmed
118	14	confirmed
119	20	confirmed
120	24	suspected
121	44	preliminary
122	14	preliminary
123	25	suspected
123	18	suspected
124	45	confirmed
125	23	confirmed
126	8	preliminary
127	13	confirmed
127	10	confirmed
127	1	confirmed
128	9	suspected
128	30	suspected
128	27	confirmed
129	25	confirmed
129	42	preliminary
129	41	confirmed
130	28	preliminary
131	18	preliminary
131	35	preliminary
131	22	preliminary
132	38	preliminary
132	8	preliminary
133	22	suspected
134	8	suspected
134	28	preliminary
134	25	suspected
135	31	suspected
135	4	suspected
136	14	preliminary
136	19	suspected
136	7	confirmed
137	44	preliminary
138	13	suspected
138	28	preliminary
138	29	preliminary
139	3	preliminary
139	45	preliminary
140	2	suspected
140	43	confirmed
141	33	confirmed
141	43	preliminary
141	12	preliminary
142	12	preliminary
142	19	suspected
142	3	preliminary
143	3	suspected
144	36	confirmed
144	6	confirmed
144	40	preliminary
145	15	confirmed
146	12	preliminary
147	28	preliminary
148	23	confirmed
148	22	preliminary
149	17	suspected
149	9	suspected
149	12	confirmed
150	17	suspected
150	13	confirmed
150	12	suspected
151	32	suspected
151	15	suspected
152	9	suspected
153	36	suspected
153	1	confirmed
154	34	confirmed
154	16	confirmed
155	36	confirmed
155	3	confirmed
156	23	suspected
157	34	preliminary
157	26	preliminary
157	42	suspected
158	13	confirmed
158	21	suspected
158	44	suspected
159	20	confirmed
159	8	suspected
160	6	confirmed
160	27	preliminary
160	11	confirmed
161	12	confirmed
161	28	suspected
161	18	confirmed
162	40	confirmed
163	21	confirmed
163	16	confirmed
163	40	confirmed
164	3	confirmed
164	5	confirmed
164	41	confirmed
165	13	suspected
165	5	suspected
166	16	preliminary
166	33	suspected
166	28	preliminary
167	23	preliminary
168	2	suspected
168	27	suspected
168	37	preliminary
169	15	preliminary
170	28	suspected
170	36	suspected
171	44	suspected
171	12	preliminary
172	38	confirmed
172	22	preliminary
172	21	suspected
173	7	confirmed
173	27	preliminary
174	34	suspected
174	27	confirmed
175	40	preliminary
176	4	suspected
176	41	suspected
176	40	confirmed
177	40	preliminary
177	3	confirmed
177	42	preliminary
178	17	preliminary
178	36	preliminary
178	21	suspected
179	1	confirmed
179	31	preliminary
180	14	confirmed
181	33	confirmed
182	28	suspected
183	45	suspected
183	34	confirmed
184	10	confirmed
184	30	confirmed
185	41	preliminary
186	37	confirmed
187	14	preliminary
188	18	preliminary
188	39	suspected
189	39	suspected
189	26	preliminary
190	12	preliminary
191	12	suspected
192	40	suspected
193	22	preliminary
193	2	preliminary
193	38	suspected
194	12	suspected
194	38	preliminary
195	22	suspected
195	9	suspected
196	42	confirmed
196	34	preliminary
197	31	suspected
197	36	suspected
198	43	confirmed
198	32	confirmed
199	41	suspected
199	16	suspected
199	27	confirmed
200	31	preliminary
200	44	confirmed
200	27	suspected
201	24	preliminary
201	25	suspected
202	45	preliminary
202	44	preliminary
202	14	suspected
203	24	preliminary
204	2	suspected
204	37	preliminary
204	28	confirmed
205	3	preliminary
206	29	preliminary
206	18	confirmed
207	31	suspected
207	12	confirmed
208	20	confirmed
208	29	suspected
209	45	preliminary
209	36	preliminary
209	16	confirmed
210	38	suspected
211	39	suspected
211	43	preliminary
211	10	confirmed
212	31	confirmed
212	34	preliminary
212	43	preliminary
213	27	preliminary
213	25	confirmed
214	19	confirmed
214	37	preliminary
215	19	confirmed
215	38	confirmed
215	35	confirmed
216	2	suspected
216	29	preliminary
217	27	suspected
218	8	suspected
218	13	preliminary
218	38	preliminary
219	27	preliminary
219	23	suspected
220	38	preliminary
221	8	suspected
222	18	confirmed
222	31	suspected
222	10	confirmed
223	23	preliminary
224	13	suspected
224	36	suspected
224	22	suspected
225	5	suspected
225	22	suspected
226	15	preliminary
227	11	preliminary
227	23	suspected
228	34	suspected
228	45	suspected
228	13	suspected
229	4	suspected
229	23	preliminary
230	28	preliminary
231	45	confirmed
231	44	confirmed
232	32	suspected
232	38	suspected
232	15	suspected
233	5	confirmed
233	29	suspected
234	21	preliminary
234	16	preliminary
235	41	suspected
236	21	suspected
237	26	preliminary
237	17	preliminary
238	33	preliminary
239	36	suspected
240	14	confirmed
240	37	confirmed
241	18	suspected
241	20	preliminary
242	4	preliminary
243	24	suspected
243	38	suspected
244	38	preliminary
244	41	confirmed
244	24	confirmed
245	41	suspected
245	17	suspected
246	19	preliminary
246	36	preliminary
247	11	confirmed
247	44	preliminary
248	37	preliminary
248	45	preliminary
248	13	confirmed
249	42	suspected
249	10	confirmed
250	10	suspected
251	11	suspected
251	30	confirmed
251	8	preliminary
252	19	confirmed
252	29	preliminary
253	2	suspected
254	33	preliminary
254	12	preliminary
254	30	confirmed
255	5	suspected
255	4	confirmed
256	25	suspected
257	23	suspected
257	19	confirmed
258	29	confirmed
258	39	confirmed
258	6	preliminary
259	42	confirmed
260	32	suspected
260	9	confirmed
261	15	suspected
261	10	confirmed
262	22	confirmed
263	38	confirmed
263	33	preliminary
263	7	preliminary
264	39	suspected
264	45	preliminary
264	15	confirmed
265	23	confirmed
265	25	suspected
266	18	preliminary
266	42	confirmed
266	11	preliminary
267	1	preliminary
268	22	suspected
268	21	suspected
269	18	suspected
270	21	confirmed
270	7	preliminary
270	5	suspected
271	4	preliminary
271	18	suspected
272	20	preliminary
273	23	confirmed
273	13	confirmed
273	8	confirmed
274	12	suspected
275	30	preliminary
275	1	preliminary
275	45	confirmed
276	27	preliminary
276	5	confirmed
277	15	confirmed
277	34	confirmed
277	33	suspected
278	27	preliminary
278	12	confirmed
279	15	confirmed
279	16	preliminary
279	28	confirmed
280	4	suspected
280	10	confirmed
280	3	preliminary
281	42	preliminary
281	16	preliminary
281	32	preliminary
282	13	suspected
282	40	preliminary
283	17	suspected
284	17	preliminary
285	9	suspected
286	45	suspected
286	32	confirmed
286	31	suspected
287	7	suspected
288	7	confirmed
288	31	confirmed
289	9	preliminary
289	20	suspected
290	18	confirmed
290	19	confirmed
291	22	suspected
291	29	confirmed
291	44	confirmed
292	11	confirmed
292	28	preliminary
292	24	suspected
293	41	preliminary
293	1	suspected
293	7	suspected
294	4	suspected
294	45	confirmed
295	10	suspected
295	34	preliminary
296	8	confirmed
297	29	preliminary
297	11	confirmed
297	39	confirmed
298	33	preliminary
299	36	suspected
299	42	suspected
299	14	suspected
300	21	confirmed
301	30	confirmed
301	45	suspected
302	31	suspected
302	22	suspected
302	41	suspected
303	29	preliminary
303	10	confirmed
303	25	confirmed
304	18	confirmed
304	9	suspected
305	36	confirmed
305	39	suspected
306	11	suspected
306	8	confirmed
306	45	suspected
307	26	suspected
307	30	suspected
307	25	preliminary
308	37	preliminary
308	34	suspected
308	5	confirmed
309	20	preliminary
310	4	preliminary
311	5	preliminary
312	28	suspected
312	38	preliminary
313	29	confirmed
313	9	preliminary
314	16	preliminary
315	35	preliminary
315	42	confirmed
315	21	preliminary
316	5	confirmed
317	19	suspected
318	15	suspected
318	13	suspected
319	44	preliminary
319	11	suspected
320	25	suspected
320	41	confirmed
320	45	suspected
321	14	confirmed
321	33	preliminary
321	32	suspected
322	20	suspected
322	8	confirmed
323	10	preliminary
323	17	confirmed
324	10	suspected
324	2	suspected
325	15	confirmed
326	27	confirmed
326	38	preliminary
327	26	preliminary
327	11	suspected
327	8	preliminary
328	4	confirmed
328	16	confirmed
328	30	suspected
329	33	confirmed
329	9	preliminary
330	31	confirmed
330	4	suspected
330	25	suspected
331	24	suspected
331	14	suspected
332	26	suspected
332	30	preliminary
332	32	suspected
333	43	confirmed
333	42	preliminary
334	11	suspected
335	36	preliminary
335	12	suspected
335	38	preliminary
336	8	confirmed
337	42	confirmed
337	7	confirmed
337	40	suspected
338	31	confirmed
338	21	confirmed
339	11	suspected
340	21	confirmed
340	2	preliminary
341	23	suspected
341	44	preliminary
342	1	suspected
342	39	preliminary
343	34	suspected
344	33	suspected
345	21	confirmed
345	22	confirmed
345	38	suspected
346	19	suspected
346	32	preliminary
346	35	preliminary
347	25	suspected
347	24	confirmed
348	11	suspected
348	19	confirmed
349	33	suspected
349	41	suspected
349	32	preliminary
350	35	confirmed
350	25	confirmed
351	38	confirmed
352	28	preliminary
352	11	preliminary
352	21	suspected
353	15	suspected
354	5	preliminary
355	4	suspected
355	1	suspected
356	35	suspected
356	8	suspected
356	45	confirmed
357	24	preliminary
358	32	suspected
358	23	confirmed
359	16	preliminary
359	40	confirmed
360	5	suspected
360	29	suspected
360	31	suspected
361	25	suspected
361	5	confirmed
361	20	confirmed
362	14	confirmed
362	37	suspected
363	37	preliminary
363	7	preliminary
363	14	confirmed
364	37	preliminary
364	14	preliminary
365	14	preliminary
365	10	suspected
365	23	confirmed
366	20	preliminary
366	24	preliminary
367	17	confirmed
367	28	suspected
367	33	confirmed
368	16	confirmed
368	36	suspected
368	28	suspected
369	44	suspected
370	6	suspected
371	35	suspected
372	38	confirmed
372	44	suspected
373	44	preliminary
374	29	confirmed
374	6	preliminary
375	44	suspected
376	31	confirmed
376	25	confirmed
377	11	suspected
377	21	confirmed
377	25	confirmed
378	5	preliminary
379	42	preliminary
379	23	preliminary
379	13	suspected
380	36	suspected
380	24	suspected
380	14	preliminary
381	23	confirmed
381	39	preliminary
382	19	suspected
382	32	suspected
382	21	preliminary
383	44	suspected
384	33	preliminary
384	4	preliminary
385	30	suspected
385	24	confirmed
385	15	suspected
386	36	suspected
386	37	suspected
387	8	suspected
387	23	preliminary
388	9	preliminary
388	36	confirmed
389	5	suspected
390	26	preliminary
390	6	preliminary
390	2	confirmed
391	7	confirmed
392	5	suspected
393	40	confirmed
394	16	confirmed
395	42	suspected
395	25	confirmed
396	33	confirmed
396	12	suspected
397	17	preliminary
397	8	preliminary
398	22	preliminary
399	10	suspected
399	12	confirmed
399	17	suspected
400	37	preliminary
400	36	preliminary
400	41	preliminary
401	10	preliminary
401	22	suspected
402	28	preliminary
402	22	preliminary
402	19	confirmed
403	6	preliminary
403	12	confirmed
403	45	confirmed
404	32	confirmed
405	19	confirmed
405	43	confirmed
405	30	suspected
406	15	confirmed
406	3	confirmed
406	36	preliminary
407	33	confirmed
407	11	confirmed
407	44	suspected
408	21	confirmed
408	41	suspected
409	25	suspected
409	3	confirmed
410	3	confirmed
410	4	suspected
411	45	preliminary
411	31	confirmed
411	9	preliminary
412	42	confirmed
412	21	preliminary
412	9	confirmed
413	3	suspected
414	10	preliminary
415	16	suspected
416	32	suspected
417	22	confirmed
418	18	confirmed
419	43	suspected
419	22	confirmed
419	41	suspected
420	14	suspected
420	2	suspected
420	17	preliminary
421	34	preliminary
421	8	preliminary
422	13	preliminary
423	2	preliminary
423	42	preliminary
423	4	suspected
424	43	preliminary
424	38	confirmed
425	25	confirmed
425	37	preliminary
425	19	suspected
426	43	confirmed
426	36	suspected
426	45	confirmed
427	15	confirmed
427	28	suspected
427	44	preliminary
428	23	suspected
429	12	suspected
429	14	preliminary
430	30	confirmed
430	35	preliminary
430	39	confirmed
431	15	confirmed
431	42	suspected
432	42	preliminary
432	6	preliminary
433	31	suspected
434	4	confirmed
435	11	preliminary
436	30	preliminary
436	21	preliminary
437	40	confirmed
437	34	confirmed
438	14	confirmed
438	28	suspected
438	17	preliminary
439	32	suspected
439	29	confirmed
440	35	confirmed
440	45	confirmed
440	18	confirmed
441	17	preliminary
442	28	confirmed
442	4	preliminary
442	26	suspected
443	38	suspected
443	42	preliminary
443	35	preliminary
444	11	preliminary
444	14	confirmed
445	13	confirmed
445	16	preliminary
446	34	suspected
446	14	suspected
447	32	confirmed
448	15	suspected
448	22	suspected
448	39	preliminary
449	15	confirmed
450	11	preliminary
451	5	suspected
451	19	confirmed
452	9	preliminary
452	4	preliminary
452	34	suspected
453	12	suspected
453	6	confirmed
454	37	confirmed
454	9	confirmed
454	11	preliminary
455	34	preliminary
455	40	preliminary
456	4	suspected
457	2	preliminary
457	28	suspected
458	37	preliminary
458	4	suspected
458	30	confirmed
459	1	preliminary
459	34	suspected
460	11	confirmed
460	29	suspected
460	5	suspected
461	40	confirmed
462	25	preliminary
462	18	confirmed
463	14	preliminary
463	18	confirmed
463	45	suspected
464	3	suspected
464	10	confirmed
464	34	preliminary
465	43	suspected
465	8	preliminary
466	31	preliminary
467	40	suspected
468	6	preliminary
468	9	confirmed
469	22	preliminary
469	6	preliminary
470	30	confirmed
470	5	suspected
471	3	preliminary
472	4	preliminary
472	3	suspected
472	2	suspected
473	28	preliminary
473	22	preliminary
474	12	preliminary
475	16	preliminary
475	17	preliminary
476	18	preliminary
476	32	suspected
476	37	confirmed
477	18	confirmed
477	3	suspected
478	19	suspected
479	38	preliminary
479	30	confirmed
480	35	confirmed
480	7	confirmed
481	20	suspected
481	7	confirmed
481	25	confirmed
482	42	suspected
482	20	suspected
483	28	suspected
483	14	suspected
483	27	preliminary
484	9	confirmed
485	32	preliminary
486	14	preliminary
486	20	preliminary
486	10	confirmed
487	24	suspected
487	18	confirmed
488	14	suspected
488	37	preliminary
488	11	confirmed
489	24	suspected
489	15	suspected
490	34	preliminary
490	24	preliminary
491	36	confirmed
491	20	confirmed
492	5	preliminary
492	24	confirmed
492	45	confirmed
493	17	suspected
494	19	preliminary
494	43	suspected
494	25	suspected
495	33	confirmed
496	2	suspected
496	34	confirmed
496	37	confirmed
497	22	preliminary
497	9	confirmed
498	11	confirmed
499	39	preliminary
499	22	preliminary
499	32	preliminary
500	6	confirmed
\.


--
-- Data for Name: visits; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.visits (visit_id, patient_id, worker_id, visit_date, visit_type, symptoms, temperature, blood_pressure_systolic, blood_pressure_diastolic, heart_rate) FROM stdin;
501	59	64	2025-07-29 02:38:53.517258+03	tests	\N	37.7	103	74	92
1	72	61	2024-12-27 06:33:01.158497+03	surgery	Chest pain and shortness of breath	37.4	149	81	64
2	112	51	2025-05-01 03:13:01.158497+03	treatment	Gastrointestinal issues	37.5	145	74	82
3	114	8	2025-09-27 16:26:01.158497+03	tests	Respiratory infection symptoms	36.3	124	62	78
4	71	13	2025-03-18 05:20:01.158497+03	tests	Respiratory infection symptoms	35.9	154	73	108
5	105	56	2025-08-20 20:29:01.158497+03	examination	Allergic reaction	36.3	105	68	65
6	23	13	2025-04-15 11:06:01.158497+03	consultation	\N	36.0	102	65	112
7	7	62	2025-03-07 19:31:01.158497+03	treatment	Headache, fever, and general fatigue	36.6	156	79	113
8	25	51	2025-07-02 18:58:01.158497+03	treatment	Gastrointestinal issues	38.7	156	84	75
9	99	22	2024-11-30 21:04:01.158497+03	treatment	Cough, sore throat, runny nose	36.8	136	66	69
10	85	37	2025-02-10 11:28:01.158497+03	tests	\N	38.1	131	75	93
11	2	18	2025-08-08 14:34:01.158497+03	tests	Routine checkup - no symptoms	37.0	115	66	75
12	75	52	2025-01-10 21:41:01.158497+03	consultation	Abdominal pain, nausea, vomiting	37.2	153	67	115
13	6	26	2025-05-03 03:56:01.158497+03	tests	Skin rash and itching	37.1	135	72	86
14	73	49	2025-11-05 05:31:01.158497+03	treatment	Abdominal pain, nausea, vomiting	35.6	147	73	114
15	19	53	2025-08-19 02:00:01.158497+03	consultation	Chest pain and shortness of breath	35.6	150	83	70
16	89	44	2025-06-04 17:05:01.158497+03	surgery	\N	36.7	141	67	96
17	1	22	2025-02-27 20:40:01.158497+03	treatment	High blood pressure symptoms	36.1	131	85	109
18	99	40	2025-10-02 08:31:01.158497+03	consultation	Skin rash and itching	36.3	141	88	100
19	69	30	2025-08-06 11:18:01.158497+03	tests	Cardiac symptoms	38.7	153	61	105
20	37	42	2025-10-25 07:27:01.158497+03	examination	\N	36.3	116	65	92
21	4	32	2024-12-02 12:31:01.158497+03	tests	\N	37.2	157	67	112
22	114	41	2024-12-16 09:27:01.158497+03	examination	Routine checkup - no symptoms	38.1	124	65	83
23	65	22	2025-02-05 01:55:01.158497+03	tests	Chest pain and shortness of breath	36.4	125	70	87
24	87	7	2024-12-16 12:19:01.158497+03	consultation	High blood pressure symptoms	36.6	127	89	72
25	45	30	2025-06-08 03:15:01.158497+03	examination	Gastrointestinal issues	37.5	152	73	74
26	33	54	2025-03-09 03:24:01.158497+03	consultation	Joint pain and swelling	37.2	126	72	78
27	7	14	2025-06-03 02:58:01.158497+03	consultation	Respiratory infection symptoms	37.4	123	89	82
28	92	51	2025-09-05 14:22:01.158497+03	treatment	Chest pain and shortness of breath	38.6	153	80	71
29	42	13	2025-05-18 20:36:01.158497+03	surgery	Skin rash and itching	35.6	106	67	77
30	85	60	2025-10-01 05:28:01.158497+03	surgery	\N	36.4	147	65	69
31	109	17	2024-12-06 15:46:01.158497+03	treatment	Gastrointestinal issues	38.7	106	84	93
32	8	31	2025-11-02 12:02:01.158497+03	treatment	Joint pain and swelling	36.2	134	63	85
33	26	25	2025-07-14 17:33:01.158497+03	treatment	Gastrointestinal issues	36.3	149	72	92
34	23	11	2024-11-28 22:44:01.158497+03	tests	Headache, fever, and general fatigue	37.7	154	61	80
35	66	17	2025-04-08 12:03:01.158497+03	examination	\N	35.8	103	61	84
36	38	18	2025-06-21 11:23:01.158497+03	treatment	Neurological symptoms	36.0	115	89	71
37	6	28	2025-06-18 10:03:01.158497+03	tests	Chest pain and shortness of breath	36.8	101	62	94
38	118	56	2025-10-22 08:38:01.158497+03	surgery	Cough, sore throat, runny nose	36.8	152	81	80
39	46	13	2025-05-06 22:42:01.158497+03	tests	Cardiac symptoms	36.9	146	83	115
40	79	10	2025-04-01 16:58:01.158497+03	consultation	Allergic reaction	36.8	148	65	104
41	96	29	2025-04-16 17:09:01.158497+03	surgery	Back pain and muscle stiffness	37.0	129	66	113
42	8	31	2025-08-18 02:33:01.158497+03	treatment	Neurological symptoms	38.8	158	86	67
43	70	47	2025-08-10 04:33:01.158497+03	surgery	Respiratory infection symptoms	35.6	148	62	91
44	87	57	2025-03-26 06:37:01.158497+03	examination	High blood pressure symptoms	36.5	102	83	105
45	59	53	2025-04-30 23:38:01.158497+03	treatment	Respiratory infection symptoms	38.6	148	77	85
46	57	50	2025-08-16 15:25:01.158497+03	examination	Allergic reaction	36.0	100	85	80
47	115	44	2025-05-19 11:01:01.158497+03	surgery	\N	38.0	125	66	108
48	110	35	2025-05-14 20:35:01.158497+03	tests	Respiratory infection symptoms	37.2	122	69	103
49	22	54	2025-10-17 08:58:01.158497+03	treatment	\N	36.1	144	89	68
50	106	33	2025-05-19 15:30:01.158497+03	examination	Cough, sore throat, runny nose	36.1	135	78	110
51	9	32	2024-12-23 11:36:01.158497+03	surgery	Chest pain and shortness of breath	36.3	128	79	94
52	73	3	2025-04-24 14:41:01.158497+03	treatment	\N	38.5	150	69	106
53	6	60	2025-05-18 23:12:01.158497+03	tests	Dizziness and weakness	37.4	139	63	105
54	56	23	2025-07-21 19:12:01.158497+03	treatment	Cardiac symptoms	35.5	119	62	117
55	74	29	2025-07-13 12:34:01.158497+03	treatment	Allergic reaction	38.3	137	62	99
56	45	17	2025-03-26 10:42:01.158497+03	surgery	Skin rash and itching	35.6	152	71	81
57	97	29	2025-08-12 23:41:01.158497+03	examination	\N	38.1	135	83	118
58	31	41	2025-01-17 23:52:01.158497+03	examination	\N	37.1	147	88	62
59	64	51	2025-05-14 02:55:01.158497+03	surgery	Abdominal pain, nausea, vomiting	38.9	133	77	116
60	93	44	2025-11-14 19:48:01.158497+03	tests	Chest pain and shortness of breath	37.0	116	79	97
61	110	13	2025-10-30 03:56:01.158497+03	treatment	Joint pain and swelling	36.5	112	73	64
62	56	11	2025-10-19 03:58:01.158497+03	consultation	Dizziness and weakness	37.2	101	82	90
63	109	47	2024-12-03 09:17:01.158497+03	consultation	Abdominal pain, nausea, vomiting	36.5	100	81	107
64	29	58	2025-06-10 17:04:01.158497+03	consultation	Chest pain and shortness of breath	36.1	105	65	105
65	57	44	2024-12-20 01:37:01.158497+03	treatment	Respiratory infection symptoms	35.8	136	83	101
66	28	34	2025-06-25 04:36:01.158497+03	tests	Dizziness and weakness	36.1	147	80	115
67	113	35	2025-08-28 03:22:01.158497+03	treatment	Respiratory infection symptoms	39.0	152	79	70
68	7	32	2025-09-17 22:15:01.158497+03	examination	Respiratory infection symptoms	36.3	111	81	64
69	83	6	2025-01-14 00:41:01.158497+03	surgery	Dizziness and weakness	36.6	147	86	90
70	79	37	2025-05-23 11:53:01.158497+03	surgery	\N	36.5	104	84	94
71	65	17	2024-11-28 07:39:01.158497+03	consultation	\N	36.2	117	62	65
72	67	26	2025-03-17 20:30:01.158497+03	treatment	Cardiac symptoms	37.5	126	86	107
73	117	7	2024-12-16 03:31:01.158497+03	tests	Routine checkup - no symptoms	36.4	118	63	118
74	107	7	2025-06-17 13:23:01.158497+03	examination	\N	37.3	138	66	91
75	40	42	2025-11-06 17:55:01.158497+03	consultation	Headache, fever, and general fatigue	38.8	137	63	83
76	115	48	2025-03-16 17:51:01.158497+03	treatment	Back pain and muscle stiffness	36.6	108	77	107
77	15	57	2025-09-07 03:39:01.158497+03	tests	Dizziness and weakness	38.9	116	70	111
78	22	59	2025-01-31 07:57:01.158497+03	tests	\N	37.9	119	87	107
79	106	23	2025-08-16 02:18:01.158497+03	treatment	Skin rash and itching	37.8	142	66	101
80	93	19	2025-08-17 14:06:01.158497+03	tests	\N	36.4	112	68	62
81	92	21	2025-05-01 22:24:01.158497+03	treatment	Cough, sore throat, runny nose	36.3	116	70	66
82	43	42	2025-02-16 12:21:01.158497+03	examination	Gastrointestinal issues	37.0	133	81	109
83	37	53	2025-01-22 15:44:01.158497+03	surgery	\N	36.4	109	76	109
84	12	30	2025-02-15 05:28:01.158497+03	treatment	Skin rash and itching	36.2	134	82	83
85	42	47	2025-02-14 09:48:01.158497+03	treatment	\N	36.1	146	71	116
86	80	56	2025-01-08 15:48:01.158497+03	consultation	High blood pressure symptoms	35.7	140	66	111
87	57	2	2025-01-21 04:48:01.158497+03	surgery	High blood pressure symptoms	37.1	136	60	114
88	35	10	2025-05-17 06:15:01.158497+03	treatment	Headache, fever, and general fatigue	38.5	127	73	96
89	60	49	2025-08-11 09:58:01.158497+03	tests	Chest pain and shortness of breath	38.1	143	79	117
90	75	57	2025-09-01 20:23:01.158497+03	examination	\N	36.7	118	89	105
91	78	45	2025-04-28 09:55:01.158497+03	consultation	\N	35.9	108	72	101
92	74	28	2025-03-10 19:28:01.158497+03	tests	Dizziness and weakness	36.1	148	86	88
93	91	26	2025-03-26 02:59:01.158497+03	treatment	Cough, sore throat, runny nose	37.4	116	80	75
94	31	53	2025-08-12 10:51:01.158497+03	treatment	Abdominal pain, nausea, vomiting	38.0	110	66	107
95	69	48	2025-09-13 21:13:01.158497+03	treatment	\N	36.9	147	76	102
96	76	50	2025-10-11 12:39:01.158497+03	tests	Skin rash and itching	37.3	104	79	87
97	67	58	2025-02-10 06:48:01.158497+03	treatment	\N	38.3	110	74	78
98	31	53	2024-12-23 01:32:01.158497+03	tests	Routine checkup - no symptoms	37.8	112	61	96
99	100	45	2025-04-09 10:36:01.158497+03	surgery	Headache, fever, and general fatigue	38.0	145	65	60
100	56	12	2025-10-14 16:26:01.158497+03	surgery	Back pain and muscle stiffness	36.3	148	67	76
101	2	36	2025-09-12 15:09:01.158497+03	consultation	High blood pressure symptoms	37.9	143	74	62
102	115	51	2025-01-23 05:20:01.158497+03	surgery	High blood pressure symptoms	38.4	150	82	100
103	4	33	2025-03-01 18:23:01.158497+03	consultation	High blood pressure symptoms	36.6	109	78	74
104	81	19	2024-11-30 20:10:01.158497+03	treatment	\N	35.5	112	79	118
105	79	9	2025-10-24 16:19:01.158497+03	consultation	\N	38.7	152	68	84
106	72	48	2025-08-08 16:24:01.158497+03	surgery	Chest pain and shortness of breath	37.9	117	61	96
107	3	18	2025-01-07 13:21:01.158497+03	surgery	Skin rash and itching	38.2	131	77	101
108	59	36	2025-08-26 03:58:01.158497+03	examination	Respiratory infection symptoms	36.1	118	74	62
109	31	33	2025-05-10 22:42:01.158497+03	treatment	Dizziness and weakness	36.3	129	81	60
110	104	10	2025-01-03 22:14:01.158497+03	surgery	Skin rash and itching	36.3	120	85	78
111	64	5	2025-09-04 03:23:01.158497+03	consultation	\N	37.8	107	80	61
112	116	7	2025-03-09 00:47:01.158497+03	consultation	Chest pain and shortness of breath	38.6	108	74	63
113	27	38	2025-06-11 00:10:01.158497+03	treatment	Allergic reaction	36.2	128	62	94
114	17	35	2024-11-21 00:51:01.158497+03	consultation	Headache, fever, and general fatigue	37.2	108	88	103
115	20	4	2025-09-25 03:56:01.158497+03	surgery	Headache, fever, and general fatigue	38.0	139	88	68
116	39	1	2025-03-03 16:43:01.158497+03	examination	High blood pressure symptoms	36.4	124	88	79
117	78	10	2025-05-08 05:41:01.158497+03	surgery	\N	36.7	149	65	87
118	5	6	2025-04-10 21:53:01.158497+03	tests	\N	38.5	158	87	91
119	7	24	2025-07-29 16:38:01.158497+03	tests	Headache, fever, and general fatigue	37.2	132	65	98
120	40	36	2025-03-18 05:45:01.158497+03	examination	High blood pressure symptoms	35.8	114	67	76
121	33	59	2025-08-20 18:58:01.158497+03	tests	\N	38.1	159	70	109
122	17	16	2025-07-08 11:56:01.158497+03	treatment	Cardiac symptoms	37.3	157	80	116
123	86	58	2025-07-23 18:30:01.158497+03	consultation	Chest pain and shortness of breath	36.6	130	60	90
124	45	57	2025-08-27 06:05:01.158497+03	treatment	Abdominal pain, nausea, vomiting	36.5	141	86	105
125	104	49	2025-09-14 06:47:01.158497+03	consultation	Abdominal pain, nausea, vomiting	35.9	129	67	65
126	72	23	2025-10-18 04:43:01.158497+03	examination	Respiratory infection symptoms	38.5	101	75	117
127	9	40	2025-07-28 18:10:01.158497+03	consultation	Gastrointestinal issues	35.5	122	70	103
128	111	18	2025-01-11 22:08:01.158497+03	tests	Dizziness and weakness	35.7	157	70	95
129	16	38	2025-09-15 11:32:01.158497+03	consultation	Abdominal pain, nausea, vomiting	38.5	103	89	75
130	47	57	2025-08-08 03:13:01.158497+03	tests	\N	37.4	103	64	94
131	70	32	2025-04-19 20:24:01.158497+03	treatment	Chest pain and shortness of breath	36.4	104	68	73
132	81	54	2025-06-30 05:09:01.158497+03	surgery	Neurological symptoms	36.7	100	76	75
133	109	51	2024-12-28 11:18:01.158497+03	consultation	\N	36.7	153	79	61
134	2	31	2025-04-02 01:33:01.158497+03	surgery	\N	36.0	114	67	93
135	110	39	2025-09-29 15:11:01.158497+03	consultation	Headache, fever, and general fatigue	38.3	122	83	104
136	85	29	2025-07-03 22:37:01.158497+03	examination	Gastrointestinal issues	36.9	125	87	66
137	5	49	2024-11-28 13:59:01.158497+03	tests	Dizziness and weakness	36.4	133	65	73
138	56	9	2025-06-25 04:55:01.158497+03	tests	Back pain and muscle stiffness	36.0	128	87	70
139	109	41	2025-09-15 16:32:01.158497+03	surgery	Cough, sore throat, runny nose	37.8	108	78	79
140	82	16	2025-07-31 09:39:01.158497+03	surgery	Chest pain and shortness of breath	36.9	138	84	102
141	94	44	2025-08-05 08:45:01.158497+03	treatment	High blood pressure symptoms	37.4	105	73	71
142	71	52	2025-03-01 01:18:01.158497+03	examination	\N	37.1	156	88	87
143	14	3	2024-12-18 09:21:01.158497+03	consultation	\N	37.1	153	73	91
144	55	56	2025-09-12 13:16:01.158497+03	consultation	Neurological symptoms	36.9	138	83	108
145	8	61	2025-01-19 02:51:01.158497+03	consultation	Respiratory infection symptoms	37.4	126	72	112
146	93	44	2025-05-17 21:13:01.158497+03	treatment	Back pain and muscle stiffness	38.5	118	73	70
147	52	36	2025-01-14 03:48:01.158497+03	surgery	Gastrointestinal issues	37.5	137	65	69
148	88	61	2025-01-09 16:04:01.158497+03	treatment	Gastrointestinal issues	38.3	121	80	103
149	22	53	2025-04-20 10:52:01.158497+03	surgery	Headache, fever, and general fatigue	38.1	114	85	103
150	11	4	2025-04-02 15:06:01.158497+03	tests	Cough, sore throat, runny nose	36.0	101	77	68
151	105	5	2025-06-08 22:16:01.158497+03	consultation	Cough, sore throat, runny nose	36.8	113	88	115
152	23	51	2024-12-03 17:45:01.158497+03	treatment	\N	36.9	151	76	61
153	82	42	2025-02-07 14:48:01.158497+03	consultation	Back pain and muscle stiffness	35.5	152	67	112
154	2	49	2024-12-07 14:40:01.158497+03	surgery	Back pain and muscle stiffness	35.9	111	71	97
155	58	12	2025-10-11 10:15:01.158497+03	consultation	Back pain and muscle stiffness	37.0	142	88	111
156	110	53	2025-08-03 00:03:01.158497+03	consultation	\N	36.6	102	66	66
157	98	6	2024-11-28 02:05:01.158497+03	examination	Cardiac symptoms	36.3	136	64	106
158	48	62	2025-01-19 15:35:01.158497+03	surgery	Skin rash and itching	36.7	123	83	97
159	115	60	2025-08-08 08:08:01.158497+03	tests	Allergic reaction	36.6	156	87	80
160	22	3	2025-03-01 08:46:01.158497+03	surgery	Back pain and muscle stiffness	36.7	119	78	70
161	21	27	2024-12-25 03:58:01.158497+03	tests	Cardiac symptoms	38.3	127	68	81
162	6	56	2025-03-28 11:21:01.158497+03	treatment	Allergic reaction	36.0	138	72	68
163	114	11	2024-11-19 01:47:01.158497+03	consultation	\N	37.6	105	74	98
164	30	13	2025-09-18 19:29:01.158497+03	consultation	\N	36.5	101	60	116
165	64	4	2024-11-23 02:26:01.158497+03	examination	High blood pressure symptoms	35.5	142	73	102
166	78	41	2025-09-16 20:32:01.158497+03	consultation	Cardiac symptoms	36.8	114	66	65
167	97	41	2025-02-16 21:08:01.158497+03	treatment	Cough, sore throat, runny nose	36.4	131	60	78
168	97	1	2025-07-11 01:55:01.158497+03	examination	Headache, fever, and general fatigue	38.7	146	88	85
169	102	35	2024-12-14 00:41:01.158497+03	examination	Cough, sore throat, runny nose	38.5	110	81	98
170	29	54	2025-01-27 23:54:01.158497+03	tests	High blood pressure symptoms	37.6	107	62	87
171	75	51	2025-08-02 13:32:01.158497+03	treatment	\N	35.6	109	88	82
172	101	51	2024-12-18 23:05:01.158497+03	tests	\N	36.6	127	72	77
173	47	2	2025-10-24 16:51:01.158497+03	tests	Back pain and muscle stiffness	38.8	157	80	80
174	88	26	2024-11-30 13:01:01.158497+03	treatment	\N	37.3	112	72	90
175	13	25	2025-03-08 01:40:01.158497+03	tests	\N	35.8	121	78	106
176	85	41	2025-03-13 16:48:01.158497+03	consultation	\N	36.6	139	79	87
177	31	44	2025-05-17 09:50:01.158497+03	treatment	Back pain and muscle stiffness	37.3	111	77	115
178	110	36	2025-02-24 02:17:01.158497+03	consultation	Back pain and muscle stiffness	36.2	159	86	69
179	116	9	2024-12-29 10:22:01.158497+03	treatment	Chest pain and shortness of breath	38.3	134	78	71
180	109	48	2025-02-20 12:24:01.158497+03	consultation	Skin rash and itching	37.2	153	84	100
181	108	47	2025-08-27 00:35:01.158497+03	treatment	Cardiac symptoms	38.3	153	69	74
182	30	34	2025-10-10 12:29:01.158497+03	consultation	Cough, sore throat, runny nose	35.6	155	87	65
183	26	19	2025-06-11 20:25:01.158497+03	examination	Headache, fever, and general fatigue	38.9	113	75	92
184	26	4	2025-05-05 20:26:01.158497+03	treatment	Headache, fever, and general fatigue	37.9	123	87	105
185	67	30	2024-11-21 10:48:01.158497+03	examination	Cardiac symptoms	37.7	151	76	94
186	23	38	2025-01-08 19:01:01.158497+03	treatment	High blood pressure symptoms	37.1	121	69	70
187	13	20	2025-10-09 16:26:01.158497+03	tests	Neurological symptoms	38.3	118	83	105
188	1	34	2025-09-21 05:44:01.158497+03	surgery	Cardiac symptoms	37.7	130	81	96
189	101	12	2025-10-07 01:29:01.158497+03	treatment	Respiratory infection symptoms	36.1	151	71	113
190	79	22	2025-08-04 10:21:01.158497+03	treatment	Respiratory infection symptoms	36.9	145	65	71
191	21	4	2025-02-03 01:44:01.158497+03	surgery	\N	37.5	137	65	104
192	101	60	2025-10-09 13:45:01.158497+03	examination	Abdominal pain, nausea, vomiting	36.2	144	70	95
193	44	6	2025-03-08 20:51:01.158497+03	tests	Cardiac symptoms	38.8	109	80	78
194	108	61	2025-04-25 06:04:01.158497+03	surgery	Routine checkup - no symptoms	38.7	116	66	117
195	34	45	2025-02-22 23:05:01.158497+03	consultation	Joint pain and swelling	36.2	156	71	89
196	58	33	2025-01-17 11:15:01.158497+03	treatment	Joint pain and swelling	38.0	152	80	83
197	107	15	2025-10-18 10:56:01.158497+03	surgery	Chest pain and shortness of breath	35.8	105	88	112
198	42	41	2025-04-28 06:51:01.158497+03	consultation	High blood pressure symptoms	37.4	153	69	101
199	56	7	2025-05-21 13:43:01.158497+03	treatment	Respiratory infection symptoms	35.5	113	77	82
200	11	47	2025-04-14 14:33:01.158497+03	tests	Cough, sore throat, runny nose	38.2	150	72	86
201	21	46	2025-11-02 04:10:01.158497+03	surgery	High blood pressure symptoms	38.3	103	74	111
202	113	46	2025-11-05 13:45:01.158497+03	treatment	Back pain and muscle stiffness	35.8	145	81	113
203	74	17	2025-09-07 22:35:01.158497+03	examination	Chest pain and shortness of breath	38.5	111	73	105
204	82	4	2025-06-13 06:38:01.158497+03	surgery	Gastrointestinal issues	35.8	107	66	94
205	79	45	2025-02-06 15:52:01.158497+03	examination	Abdominal pain, nausea, vomiting	38.2	138	61	111
206	26	21	2025-05-31 11:48:01.158497+03	surgery	Cardiac symptoms	39.0	142	77	63
207	19	17	2025-04-29 09:35:01.158497+03	tests	Allergic reaction	38.8	142	66	95
208	13	45	2025-10-30 15:25:01.158497+03	consultation	Cough, sore throat, runny nose	38.0	150	77	66
209	28	41	2025-10-09 08:24:01.158497+03	consultation	Allergic reaction	37.4	143	71	69
210	12	13	2025-05-24 23:33:01.158497+03	treatment	Joint pain and swelling	36.1	158	76	96
211	80	28	2025-07-14 09:17:01.158497+03	surgery	Routine checkup - no symptoms	36.2	125	71	103
212	78	16	2025-08-02 08:38:01.158497+03	tests	Gastrointestinal issues	36.2	100	74	86
213	99	28	2025-08-23 21:32:01.158497+03	surgery	Abdominal pain, nausea, vomiting	37.4	117	88	85
214	116	16	2025-01-12 06:26:01.158497+03	surgery	Abdominal pain, nausea, vomiting	37.1	158	79	75
215	65	9	2025-10-07 05:50:01.158497+03	treatment	Dizziness and weakness	38.3	146	66	111
216	32	46	2025-02-26 23:03:01.158497+03	examination	Cough, sore throat, runny nose	37.2	116	83	78
217	96	39	2025-08-13 03:38:01.158497+03	examination	Gastrointestinal issues	36.3	117	85	107
218	108	13	2025-05-31 16:43:01.158497+03	tests	Respiratory infection symptoms	35.6	129	69	76
219	106	2	2025-05-11 12:30:01.158497+03	tests	Routine checkup - no symptoms	36.0	100	75	97
220	19	33	2025-06-16 11:49:01.158497+03	consultation	\N	37.1	105	87	88
221	18	16	2025-09-26 09:39:01.158497+03	surgery	\N	37.9	102	63	68
222	34	31	2025-03-11 16:22:01.158497+03	tests	\N	36.4	145	81	80
223	37	45	2025-03-19 20:42:01.158497+03	treatment	Allergic reaction	36.3	105	83	113
224	47	58	2025-06-13 02:32:01.158497+03	treatment	Gastrointestinal issues	35.9	134	65	62
225	98	53	2025-01-07 06:27:01.158497+03	surgery	Routine checkup - no symptoms	36.8	126	69	92
226	91	17	2025-11-02 08:14:01.158497+03	examination	Abdominal pain, nausea, vomiting	37.5	149	81	64
227	104	6	2025-01-24 23:36:01.158497+03	examination	Dizziness and weakness	37.1	108	86	88
228	110	38	2025-02-16 11:54:01.158497+03	examination	Dizziness and weakness	38.7	118	60	79
229	11	51	2025-11-15 09:28:01.158497+03	treatment	Skin rash and itching	37.1	107	68	73
230	19	59	2025-07-31 11:50:01.158497+03	surgery	High blood pressure symptoms	36.9	138	65	94
231	104	63	2025-04-18 03:32:01.158497+03	surgery	Cough, sore throat, runny nose	38.6	134	69	64
232	67	9	2025-07-23 19:55:01.158497+03	treatment	\N	38.6	133	79	100
233	42	29	2025-08-27 13:20:01.158497+03	examination	Back pain and muscle stiffness	36.3	155	60	87
234	32	7	2025-03-29 11:09:01.158497+03	examination	Skin rash and itching	36.6	102	82	60
235	74	64	2025-09-18 05:13:01.158497+03	examination	Routine checkup - no symptoms	38.0	137	75	80
236	89	45	2025-05-10 14:03:01.158497+03	tests	Skin rash and itching	35.6	117	71	98
237	72	11	2025-08-19 20:01:01.158497+03	tests	\N	35.8	126	78	98
238	24	25	2025-07-28 01:30:01.158497+03	treatment	Skin rash and itching	37.1	118	75	81
239	57	28	2024-11-22 16:52:01.158497+03	surgery	Joint pain and swelling	38.6	145	60	71
240	84	37	2024-12-13 20:04:01.158497+03	tests	High blood pressure symptoms	38.6	106	78	65
241	31	53	2025-03-12 04:03:01.158497+03	treatment	Headache, fever, and general fatigue	36.3	128	80	79
242	48	55	2025-03-25 07:24:01.158497+03	surgery	Neurological symptoms	35.8	124	64	109
243	86	34	2025-11-08 01:35:01.158497+03	tests	Gastrointestinal issues	37.6	106	63	82
244	79	30	2025-06-10 19:37:01.158497+03	treatment	\N	36.5	149	83	119
245	97	21	2025-07-07 21:34:01.158497+03	tests	Abdominal pain, nausea, vomiting	37.2	129	76	91
246	117	35	2025-09-03 04:59:01.158497+03	tests	Cough, sore throat, runny nose	36.2	123	65	82
247	84	48	2025-04-25 13:48:01.158497+03	examination	\N	38.6	144	69	95
248	18	53	2025-04-13 06:39:01.158497+03	tests	Allergic reaction	36.9	105	79	76
249	106	18	2025-02-05 07:56:01.158497+03	examination	Chest pain and shortness of breath	35.8	113	70	99
250	87	55	2025-06-11 08:39:01.158497+03	consultation	Cardiac symptoms	36.5	156	62	70
251	27	10	2024-12-03 16:49:01.158497+03	tests	Routine checkup - no symptoms	37.4	115	85	88
252	89	16	2025-06-08 22:19:01.158497+03	tests	Cough, sore throat, runny nose	36.7	127	75	82
253	98	5	2025-06-04 15:22:01.158497+03	consultation	Back pain and muscle stiffness	35.7	108	67	80
254	34	5	2025-01-13 10:14:01.158497+03	examination	Joint pain and swelling	35.5	132	75	82
255	71	53	2025-09-29 20:44:01.158497+03	treatment	Gastrointestinal issues	36.7	108	73	101
256	89	16	2025-06-04 16:08:01.158497+03	consultation	Chest pain and shortness of breath	37.0	102	87	74
257	106	35	2025-08-30 01:20:01.158497+03	examination	Skin rash and itching	37.1	154	73	114
258	20	39	2025-03-21 17:43:01.158497+03	surgery	Skin rash and itching	37.9	111	85	113
259	105	35	2025-03-11 17:15:01.158497+03	treatment	Cardiac symptoms	36.4	108	70	66
260	5	57	2025-03-04 06:53:01.158497+03	treatment	Allergic reaction	36.5	153	70	118
261	56	24	2025-07-13 04:37:01.158497+03	surgery	Dizziness and weakness	38.2	146	77	87
262	21	42	2025-02-28 02:28:01.158497+03	tests	Chest pain and shortness of breath	35.7	121	71	65
263	87	21	2025-06-16 08:56:01.158497+03	consultation	Allergic reaction	35.9	133	78	82
264	43	50	2025-03-25 02:47:01.158497+03	surgery	Back pain and muscle stiffness	36.6	151	74	89
265	52	3	2025-01-24 19:54:01.158497+03	examination	Joint pain and swelling	36.7	159	67	103
266	49	37	2025-11-10 10:16:01.158497+03	examination	Neurological symptoms	36.5	150	61	90
267	112	58	2025-04-10 16:33:01.158497+03	consultation	Back pain and muscle stiffness	38.8	105	68	74
268	55	40	2024-12-05 13:14:01.158497+03	tests	\N	37.2	108	77	68
269	61	64	2024-11-30 09:26:01.158497+03	treatment	\N	37.4	114	72	70
270	53	64	2025-01-12 21:57:01.158497+03	consultation	\N	38.4	111	74	117
271	68	4	2025-08-21 19:52:01.158497+03	surgery	Skin rash and itching	35.5	116	64	116
272	36	11	2025-08-18 11:43:01.158497+03	examination	High blood pressure symptoms	37.1	113	66	116
273	44	42	2025-08-19 05:50:01.158497+03	examination	Respiratory infection symptoms	38.8	147	68	89
274	65	19	2025-10-15 00:44:01.158497+03	examination	Allergic reaction	37.3	115	70	91
275	40	48	2025-01-20 23:56:01.158497+03	treatment	\N	38.9	118	73	82
276	78	9	2025-09-13 03:29:01.158497+03	tests	Respiratory infection symptoms	36.6	124	88	64
277	3	9	2025-08-27 10:21:01.158497+03	tests	Cardiac symptoms	36.9	117	62	61
278	71	15	2025-08-11 17:58:01.158497+03	consultation	Back pain and muscle stiffness	37.0	113	75	115
279	39	5	2025-05-12 00:21:01.158497+03	consultation	Dizziness and weakness	38.4	148	64	84
280	34	1	2025-08-13 04:30:01.158497+03	tests	\N	36.8	133	79	106
281	56	35	2025-08-06 05:28:01.158497+03	examination	\N	37.2	125	81	73
282	62	16	2024-11-24 06:03:01.158497+03	treatment	Back pain and muscle stiffness	35.7	130	83	114
283	56	2	2024-12-07 07:48:01.158497+03	surgery	Respiratory infection symptoms	35.7	107	85	93
284	116	31	2024-12-03 00:58:01.158497+03	tests	Dizziness and weakness	36.1	151	60	116
285	99	30	2025-05-28 16:38:01.158497+03	consultation	High blood pressure symptoms	35.8	116	60	79
286	71	33	2024-11-21 14:10:01.158497+03	examination	Cardiac symptoms	38.9	150	86	88
287	120	61	2025-04-16 23:55:01.158497+03	treatment	Respiratory infection symptoms	38.1	123	74	72
288	93	13	2025-01-10 04:50:01.158497+03	surgery	Skin rash and itching	38.3	141	60	64
289	18	24	2025-05-08 21:43:01.158497+03	consultation	\N	37.8	121	81	96
290	1	10	2025-01-25 01:34:01.158497+03	tests	Skin rash and itching	36.0	145	89	67
291	60	11	2025-10-14 22:23:01.158497+03	surgery	Neurological symptoms	36.9	121	67	87
292	59	10	2025-01-24 13:29:01.158497+03	consultation	Abdominal pain, nausea, vomiting	36.1	159	66	115
293	118	15	2025-03-02 01:56:01.158497+03	surgery	\N	36.4	158	78	65
294	46	46	2025-02-13 00:42:01.158497+03	tests	\N	36.8	102	68	71
295	118	12	2025-02-24 18:57:01.158497+03	consultation	Back pain and muscle stiffness	35.5	137	78	105
296	38	3	2025-07-15 05:48:01.158497+03	tests	\N	37.8	125	65	117
297	96	33	2025-08-29 12:02:01.158497+03	treatment	Headache, fever, and general fatigue	36.3	130	79	93
298	18	40	2025-06-22 03:43:01.158497+03	treatment	Neurological symptoms	36.2	109	62	88
299	3	42	2025-03-13 18:13:01.158497+03	treatment	Cough, sore throat, runny nose	38.4	100	64	118
300	106	52	2025-02-14 01:34:01.158497+03	surgery	Joint pain and swelling	37.0	117	88	73
301	118	45	2025-06-26 03:15:01.158497+03	treatment	Cough, sore throat, runny nose	36.3	153	62	72
302	116	62	2025-08-31 20:37:01.158497+03	tests	Back pain and muscle stiffness	36.8	142	65	64
303	115	49	2025-11-01 16:03:01.158497+03	examination	Neurological symptoms	35.8	149	74	98
304	69	28	2025-02-08 13:51:01.158497+03	tests	Skin rash and itching	36.2	134	73	77
305	87	44	2025-04-23 05:18:01.158497+03	consultation	Cough, sore throat, runny nose	36.5	126	62	71
306	45	2	2025-03-23 19:28:01.158497+03	surgery	Chest pain and shortness of breath	37.4	136	79	71
307	102	8	2025-11-08 08:42:01.158497+03	surgery	Cough, sore throat, runny nose	36.5	112	65	65
308	99	63	2025-10-02 11:57:01.158497+03	surgery	Neurological symptoms	37.3	137	71	80
309	86	4	2025-05-09 23:51:01.158497+03	surgery	Joint pain and swelling	37.3	106	66	62
310	50	36	2025-09-04 05:50:01.158497+03	consultation	Routine checkup - no symptoms	37.1	101	83	98
311	98	49	2025-10-15 00:48:01.158497+03	examination	Allergic reaction	37.4	119	61	87
312	112	58	2025-10-27 07:59:01.158497+03	tests	Skin rash and itching	37.7	134	63	113
313	94	55	2024-12-07 23:15:01.158497+03	tests	Cardiac symptoms	35.7	143	88	117
314	8	29	2024-11-21 08:11:01.158497+03	tests	Routine checkup - no symptoms	37.1	155	82	89
315	58	4	2025-04-12 17:48:01.158497+03	examination	Back pain and muscle stiffness	35.6	113	76	94
316	35	28	2025-03-01 16:34:01.158497+03	examination	Gastrointestinal issues	36.7	122	77	99
317	10	5	2025-03-01 14:02:01.158497+03	tests	Chest pain and shortness of breath	38.0	150	74	70
318	26	48	2024-12-26 20:55:01.158497+03	consultation	Back pain and muscle stiffness	35.9	133	82	112
319	63	24	2025-06-11 20:05:01.158497+03	consultation	Chest pain and shortness of breath	38.2	136	87	65
320	116	49	2025-10-31 06:26:01.158497+03	consultation	Cough, sore throat, runny nose	38.3	145	62	80
321	7	13	2025-06-24 15:18:01.158497+03	surgery	\N	38.1	122	85	117
322	2	54	2025-07-02 06:10:01.158497+03	consultation	\N	36.8	135	80	96
323	75	20	2025-09-10 05:03:01.158497+03	treatment	Cardiac symptoms	38.5	151	84	62
324	101	59	2025-01-09 04:54:01.158497+03	surgery	Cough, sore throat, runny nose	37.7	113	89	116
325	24	59	2025-01-04 01:35:01.158497+03	tests	Headache, fever, and general fatigue	38.0	159	81	84
326	66	46	2025-02-28 11:42:01.158497+03	examination	Joint pain and swelling	35.7	154	77	76
327	118	52	2025-01-26 01:34:01.158497+03	surgery	Skin rash and itching	36.9	117	84	84
328	72	42	2025-07-11 10:14:01.158497+03	surgery	Neurological symptoms	36.2	129	66	62
329	75	7	2025-02-03 09:34:01.158497+03	consultation	Respiratory infection symptoms	37.9	125	79	66
330	108	29	2025-04-28 15:14:01.158497+03	consultation	Skin rash and itching	36.8	106	84	60
331	95	24	2025-09-24 07:32:01.158497+03	tests	Routine checkup - no symptoms	37.3	123	80	77
332	74	49	2025-09-14 02:08:01.158497+03	tests	Neurological symptoms	38.6	153	87	102
333	19	53	2025-10-30 06:54:01.158497+03	examination	Routine checkup - no symptoms	36.9	111	89	97
334	45	26	2025-08-04 19:12:01.158497+03	tests	Allergic reaction	36.8	109	79	90
335	33	17	2025-10-20 08:47:01.158497+03	surgery	Cough, sore throat, runny nose	36.9	103	60	102
336	19	10	2025-07-07 18:35:01.158497+03	treatment	High blood pressure symptoms	37.5	111	63	84
337	59	5	2025-05-14 03:06:01.158497+03	treatment	Headache, fever, and general fatigue	37.3	129	75	77
338	61	33	2025-11-03 10:15:01.158497+03	examination	Headache, fever, and general fatigue	37.4	110	65	67
339	12	2	2024-12-14 18:10:01.158497+03	treatment	Headache, fever, and general fatigue	37.6	132	67	68
340	44	48	2025-06-21 03:49:01.158497+03	examination	Dizziness and weakness	35.6	141	67	72
341	67	56	2025-10-14 10:53:01.158497+03	treatment	Headache, fever, and general fatigue	36.9	157	78	81
342	57	34	2025-08-30 10:39:01.158497+03	tests	Neurological symptoms	36.6	122	81	94
343	107	42	2025-01-12 02:52:01.158497+03	examination	Chest pain and shortness of breath	37.5	143	80	67
344	75	52	2025-10-11 11:34:01.158497+03	examination	High blood pressure symptoms	38.7	132	78	85
345	15	23	2025-04-23 04:28:01.158497+03	surgery	Cough, sore throat, runny nose	37.3	143	69	117
346	98	9	2025-04-27 09:32:01.158497+03	consultation	Routine checkup - no symptoms	36.0	157	79	114
347	79	34	2025-09-13 02:20:01.158497+03	treatment	\N	38.7	154	88	102
348	44	9	2025-08-20 12:41:01.158497+03	consultation	Headache, fever, and general fatigue	38.7	105	81	80
349	80	35	2025-07-30 17:17:01.158497+03	surgery	Headache, fever, and general fatigue	35.9	122	87	70
350	33	31	2025-11-05 02:39:01.158497+03	surgery	Cardiac symptoms	36.9	149	65	84
351	2	21	2025-10-06 23:30:01.158497+03	treatment	\N	35.9	137	69	96
352	98	57	2025-06-16 14:26:01.158497+03	examination	Allergic reaction	36.5	139	70	75
353	103	6	2025-04-29 01:19:01.158497+03	tests	Headache, fever, and general fatigue	38.0	148	78	106
354	58	49	2025-08-20 21:49:01.158497+03	examination	Skin rash and itching	38.1	118	62	104
355	6	57	2024-12-25 18:01:01.158497+03	tests	Dizziness and weakness	37.1	142	74	116
356	44	5	2025-09-10 14:09:01.158497+03	surgery	\N	35.7	103	69	76
357	92	56	2025-06-16 00:09:01.158497+03	surgery	Routine checkup - no symptoms	38.6	146	70	117
358	105	22	2025-07-07 10:08:01.158497+03	surgery	Abdominal pain, nausea, vomiting	36.9	115	71	103
359	85	61	2025-10-03 00:06:01.158497+03	surgery	Chest pain and shortness of breath	38.4	151	62	76
360	71	2	2025-10-04 15:12:01.158497+03	tests	Respiratory infection symptoms	36.5	146	64	80
361	91	3	2025-05-11 02:47:01.158497+03	consultation	Headache, fever, and general fatigue	38.5	126	88	104
362	39	58	2025-11-09 08:08:01.158497+03	treatment	\N	37.4	131	71	85
363	91	19	2025-04-09 20:25:01.158497+03	surgery	Abdominal pain, nausea, vomiting	37.4	157	77	66
364	90	4	2025-09-21 01:31:01.158497+03	treatment	\N	38.8	152	81	66
365	43	64	2025-02-05 10:57:01.158497+03	surgery	\N	37.6	129	71	105
366	12	7	2025-02-02 06:56:01.158497+03	tests	Joint pain and swelling	35.9	109	78	108
367	56	59	2025-10-10 14:21:01.158497+03	treatment	Chest pain and shortness of breath	38.8	146	88	65
368	3	37	2025-09-05 16:38:01.158497+03	consultation	Abdominal pain, nausea, vomiting	38.0	139	65	63
369	105	12	2025-09-12 03:17:01.158497+03	examination	Allergic reaction	35.8	108	60	73
370	50	10	2025-04-30 00:06:01.158497+03	surgery	\N	36.4	153	68	82
371	12	59	2025-03-19 10:03:01.158497+03	surgery	Cardiac symptoms	35.8	158	79	64
372	56	40	2025-01-27 05:39:01.158497+03	consultation	Joint pain and swelling	38.0	133	81	92
373	51	55	2025-01-26 03:32:01.158497+03	tests	\N	37.0	151	62	91
374	25	44	2025-05-22 06:19:01.158497+03	treatment	\N	35.9	115	66	100
375	19	44	2025-06-06 02:01:01.158497+03	tests	Dizziness and weakness	36.7	104	82	62
376	58	51	2025-10-05 10:44:01.158497+03	treatment	Routine checkup - no symptoms	38.9	102	62	60
377	75	46	2024-12-02 14:38:01.158497+03	tests	\N	36.1	159	88	93
378	15	61	2025-08-09 11:45:01.158497+03	tests	Dizziness and weakness	35.5	138	76	108
379	78	46	2025-02-13 09:37:01.158497+03	tests	Neurological symptoms	37.7	134	65	84
380	15	8	2024-12-18 00:41:01.158497+03	treatment	Back pain and muscle stiffness	36.8	104	81	119
381	27	2	2025-05-24 15:02:01.158497+03	consultation	Routine checkup - no symptoms	36.0	121	80	64
382	31	59	2025-11-09 18:34:01.158497+03	treatment	High blood pressure symptoms	36.2	149	68	76
383	118	61	2025-08-28 19:26:01.158497+03	surgery	Abdominal pain, nausea, vomiting	37.1	118	86	76
384	70	34	2024-12-04 13:17:01.158497+03	tests	High blood pressure symptoms	36.6	133	89	119
385	67	22	2025-07-14 17:11:01.158497+03	consultation	Gastrointestinal issues	38.2	107	86	72
386	80	44	2025-01-30 20:58:01.158497+03	consultation	Gastrointestinal issues	38.9	128	83	79
387	25	40	2024-11-28 18:24:01.158497+03	treatment	Headache, fever, and general fatigue	38.9	117	81	72
388	114	40	2025-10-13 20:16:01.158497+03	treatment	Allergic reaction	38.5	140	66	104
389	84	40	2025-09-30 02:16:01.158497+03	consultation	\N	36.6	105	77	63
390	32	15	2025-11-07 03:23:01.158497+03	consultation	Cardiac symptoms	36.0	141	79	63
391	35	37	2025-10-09 02:32:01.158497+03	consultation	Abdominal pain, nausea, vomiting	36.2	104	67	103
392	29	36	2025-08-11 13:18:01.158497+03	consultation	Headache, fever, and general fatigue	37.3	127	79	63
393	73	19	2025-09-01 18:20:01.158497+03	surgery	Allergic reaction	36.5	113	75	66
394	94	24	2025-07-21 14:41:01.158497+03	treatment	Neurological symptoms	36.5	153	68	65
395	8	35	2025-09-14 12:31:01.158497+03	treatment	Allergic reaction	35.6	159	85	112
396	53	19	2025-10-25 22:22:01.158497+03	consultation	Allergic reaction	36.2	126	74	96
397	81	55	2025-08-25 00:34:01.158497+03	surgery	\N	36.2	147	81	70
398	82	8	2025-08-08 22:30:01.158497+03	examination	\N	35.9	141	69	99
399	55	36	2024-12-18 23:24:01.158497+03	surgery	Joint pain and swelling	38.8	135	86	114
400	110	63	2025-04-28 09:06:01.158497+03	consultation	Neurological symptoms	36.3	134	64	61
401	29	56	2025-05-29 12:12:01.158497+03	examination	Respiratory infection symptoms	38.9	122	70	115
402	2	27	2025-05-28 21:15:01.158497+03	examination	Back pain and muscle stiffness	38.3	137	85	64
403	15	6	2025-03-23 09:45:01.158497+03	consultation	\N	36.2	115	87	63
404	85	55	2025-09-08 14:44:01.158497+03	consultation	Dizziness and weakness	36.4	113	67	69
405	39	56	2025-07-26 06:52:01.158497+03	surgery	Gastrointestinal issues	35.8	119	66	65
406	23	19	2025-11-04 15:19:01.158497+03	examination	Back pain and muscle stiffness	38.1	118	89	72
407	95	47	2025-06-10 20:37:01.158497+03	examination	Cardiac symptoms	36.9	111	82	85
408	34	10	2025-06-01 17:22:01.158497+03	tests	Headache, fever, and general fatigue	35.6	147	65	61
409	55	49	2025-03-24 11:00:01.158497+03	examination	High blood pressure symptoms	35.7	144	73	83
410	60	56	2025-04-11 13:28:01.158497+03	treatment	Joint pain and swelling	36.0	102	70	88
411	43	51	2025-08-12 21:58:01.158497+03	examination	Skin rash and itching	37.7	144	61	82
412	20	13	2025-08-11 00:40:01.158497+03	tests	Neurological symptoms	37.7	113	64	105
413	103	45	2024-11-19 21:44:01.158497+03	tests	Headache, fever, and general fatigue	36.2	121	75	99
414	97	61	2025-06-14 13:26:01.158497+03	tests	Neurological symptoms	37.7	137	81	108
415	119	41	2025-09-14 09:34:01.158497+03	surgery	\N	37.1	139	64	96
416	22	48	2025-08-03 09:33:01.158497+03	examination	Allergic reaction	38.1	144	76	98
417	92	10	2025-10-12 22:57:01.158497+03	treatment	Chest pain and shortness of breath	38.2	116	76	112
418	67	28	2024-12-10 05:41:01.158497+03	examination	Routine checkup - no symptoms	35.7	151	88	104
419	27	27	2025-03-19 00:47:01.158497+03	examination	Respiratory infection symptoms	38.8	143	65	63
420	115	36	2025-05-20 08:51:01.158497+03	surgery	Joint pain and swelling	38.9	125	85	95
421	98	34	2025-09-05 23:00:01.158497+03	treatment	Gastrointestinal issues	36.1	137	86	88
422	83	41	2025-11-12 18:49:01.158497+03	treatment	Cough, sore throat, runny nose	36.1	119	69	93
423	6	42	2025-04-06 03:15:01.158497+03	tests	Skin rash and itching	37.1	129	82	83
424	65	49	2025-10-10 07:35:01.158497+03	examination	Back pain and muscle stiffness	38.6	150	73	82
425	49	13	2025-03-12 00:09:01.158497+03	examination	Respiratory infection symptoms	36.7	158	76	65
426	108	33	2025-02-05 16:57:01.158497+03	consultation	\N	37.7	109	66	110
427	84	40	2025-01-30 18:55:01.158497+03	tests	Abdominal pain, nausea, vomiting	35.6	129	85	66
428	80	6	2024-12-13 04:40:01.158497+03	treatment	\N	36.1	110	83	114
429	99	39	2025-10-18 07:58:01.158497+03	tests	\N	37.2	137	85	75
430	11	25	2025-11-09 19:21:01.158497+03	surgery	\N	37.4	131	69	104
431	113	15	2025-09-07 11:30:01.158497+03	surgery	Neurological symptoms	37.1	125	61	60
432	27	47	2025-07-10 10:12:01.158497+03	consultation	Allergic reaction	35.8	120	87	76
433	77	31	2025-09-08 23:20:01.158497+03	consultation	Chest pain and shortness of breath	39.0	121	83	71
434	2	63	2025-07-09 23:53:01.158497+03	consultation	High blood pressure symptoms	38.2	113	61	82
435	36	4	2025-10-10 03:02:01.158497+03	tests	Back pain and muscle stiffness	36.8	137	88	111
436	27	32	2025-01-31 17:51:01.158497+03	tests	Joint pain and swelling	38.9	113	70	113
437	24	40	2025-05-01 01:43:01.158497+03	examination	\N	36.7	150	64	82
438	19	47	2025-06-18 14:05:01.158497+03	tests	Back pain and muscle stiffness	38.5	135	78	106
439	21	17	2025-02-13 12:19:01.158497+03	examination	Cough, sore throat, runny nose	36.5	107	86	80
440	93	58	2025-02-04 20:09:01.158497+03	treatment	Joint pain and swelling	36.3	105	89	61
441	31	26	2025-04-13 11:31:01.158497+03	treatment	Respiratory infection symptoms	37.4	128	68	88
442	45	59	2025-01-08 04:55:01.158497+03	surgery	\N	38.9	108	61	118
443	58	39	2025-05-12 18:40:01.158497+03	consultation	Cough, sore throat, runny nose	38.3	155	73	117
444	47	28	2025-10-07 03:19:01.158497+03	consultation	Gastrointestinal issues	36.3	145	88	79
445	46	13	2025-04-11 22:19:01.158497+03	consultation	Cardiac symptoms	37.2	129	74	72
446	14	41	2025-01-16 22:18:01.158497+03	examination	Back pain and muscle stiffness	38.6	108	89	114
447	80	55	2025-03-25 00:19:01.158497+03	examination	Routine checkup - no symptoms	35.7	134	73	68
448	118	31	2025-10-24 21:41:01.158497+03	consultation	Gastrointestinal issues	37.2	133	75	110
449	43	44	2025-02-01 15:40:01.158497+03	tests	Respiratory infection symptoms	37.8	127	68	107
450	14	42	2024-12-24 06:46:01.158497+03	tests	Neurological symptoms	38.4	116	77	81
451	7	6	2025-04-17 01:43:01.158497+03	examination	Back pain and muscle stiffness	36.7	135	89	100
452	110	8	2024-11-21 21:17:01.158497+03	tests	Neurological symptoms	38.5	134	80	94
453	111	48	2025-01-06 16:56:01.158497+03	examination	Back pain and muscle stiffness	36.0	130	60	92
454	101	46	2025-01-18 07:33:01.158497+03	tests	Cough, sore throat, runny nose	38.4	125	66	108
455	97	60	2024-12-26 05:49:01.158497+03	surgery	Headache, fever, and general fatigue	36.8	117	73	87
456	98	49	2025-07-14 04:47:01.158497+03	treatment	\N	38.3	107	78	82
457	46	47	2025-07-07 17:01:01.158497+03	treatment	Cardiac symptoms	36.0	133	87	101
458	37	23	2025-11-14 16:54:01.158497+03	examination	Cardiac symptoms	35.5	143	89	114
459	48	9	2025-04-24 13:30:01.158497+03	surgery	\N	38.5	133	73	68
460	21	8	2025-03-09 14:24:01.158497+03	surgery	Chest pain and shortness of breath	36.6	104	88	116
461	12	33	2025-10-18 00:36:01.158497+03	tests	Skin rash and itching	36.7	155	61	111
462	94	58	2025-04-11 12:03:01.158497+03	treatment	Chest pain and shortness of breath	36.0	137	64	113
463	63	48	2025-06-25 12:21:01.158497+03	examination	Joint pain and swelling	37.8	128	60	77
464	107	39	2024-12-15 15:03:01.158497+03	consultation	\N	37.6	117	82	73
465	59	1	2025-01-01 18:21:01.158497+03	examination	Routine checkup - no symptoms	37.4	144	81	89
466	30	9	2025-09-27 20:42:01.158497+03	treatment	\N	36.3	151	68	62
467	19	62	2025-07-22 16:38:01.158497+03	consultation	Allergic reaction	37.0	106	77	79
468	62	36	2025-01-18 02:49:01.158497+03	treatment	\N	38.9	144	64	88
469	62	35	2025-09-27 20:24:01.158497+03	tests	\N	38.8	155	63	119
470	105	2	2025-05-25 07:37:01.158497+03	treatment	Headache, fever, and general fatigue	37.3	101	74	113
471	28	41	2025-02-12 17:04:01.158497+03	tests	\N	36.3	120	69	100
472	20	39	2025-08-12 14:48:01.158497+03	examination	Headache, fever, and general fatigue	36.8	130	79	78
473	81	24	2025-01-14 23:54:01.158497+03	examination	Allergic reaction	36.9	109	68	88
474	87	49	2024-12-11 18:23:01.158497+03	treatment	Chest pain and shortness of breath	38.4	157	85	98
475	88	40	2025-02-25 15:48:01.158497+03	surgery	Gastrointestinal issues	36.4	134	84	81
476	99	22	2025-07-06 13:47:01.158497+03	examination	Chest pain and shortness of breath	35.7	103	66	117
477	87	5	2025-08-31 22:14:01.158497+03	examination	Joint pain and swelling	35.5	157	78	84
478	85	27	2025-10-16 13:28:01.158497+03	tests	Routine checkup - no symptoms	36.0	157	62	104
479	56	8	2025-01-08 13:48:01.158497+03	tests	Cardiac symptoms	37.0	104	80	63
480	61	53	2025-03-10 17:40:01.158497+03	examination	Allergic reaction	36.9	113	89	105
481	107	7	2024-12-08 03:48:01.158497+03	consultation	Cardiac symptoms	36.6	112	84	79
482	117	54	2024-12-09 18:26:01.158497+03	examination	High blood pressure symptoms	37.7	146	60	78
483	2	54	2025-07-28 09:58:01.158497+03	examination	\N	36.8	158	68	112
484	59	1	2025-05-08 12:09:01.158497+03	treatment	Neurological symptoms	36.6	138	78	105
485	37	44	2025-05-08 06:10:01.158497+03	consultation	\N	35.7	119	84	118
486	73	61	2024-11-21 23:53:01.158497+03	examination	Headache, fever, and general fatigue	36.9	112	72	92
487	113	49	2025-03-22 21:23:01.158497+03	consultation	Neurological symptoms	36.3	135	73	73
488	92	26	2025-09-01 07:25:01.158497+03	tests	Back pain and muscle stiffness	36.9	128	65	71
489	56	6	2025-09-27 23:36:01.158497+03	tests	Respiratory infection symptoms	36.9	151	68	100
490	81	61	2025-04-12 19:30:01.158497+03	examination	Headache, fever, and general fatigue	38.7	148	72	76
491	88	33	2025-01-01 22:32:01.158497+03	consultation	\N	35.6	106	84	70
492	3	52	2025-07-23 16:59:01.158497+03	consultation	\N	37.7	106	64	119
493	32	64	2025-07-05 06:10:01.158497+03	surgery	\N	36.3	131	89	116
494	70	11	2024-11-30 08:30:01.158497+03	surgery	Allergic reaction	36.9	109	82	106
495	69	53	2025-10-08 17:19:01.158497+03	consultation	Cardiac symptoms	35.9	108	68	86
496	107	64	2025-02-27 22:20:01.158497+03	consultation	Chest pain and shortness of breath	36.3	102	75	95
497	97	27	2025-06-03 17:50:01.158497+03	examination	Gastrointestinal issues	36.5	136	75	80
498	31	58	2025-04-02 23:20:01.158497+03	tests	\N	35.8	124	68	66
499	26	43	2025-08-26 13:01:01.158497+03	consultation	Headache, fever, and general fatigue	36.4	135	73	101
500	98	57	2025-03-20 20:17:01.158497+03	treatment	Abdominal pain, nausea, vomiting	38.2	109	72	85
\.


--
-- Name: clinics_clinic_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.clinics_clinic_id_seq', 3, true);


--
-- Name: diagnoses_diagnosis_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.diagnoses_diagnosis_id_seq', 45, true);


--
-- Name: medical_tests_test_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.medical_tests_test_id_seq', 730, true);


--
-- Name: medical_workers_worker_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.medical_workers_worker_id_seq', 64, true);


--
-- Name: patients_patient_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.patients_patient_id_seq', 120, true);


--
-- Name: prescriptions_prescription_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.prescriptions_prescription_id_seq', 1002, true);


--
-- Name: specializations_specialization_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.specializations_specialization_id_seq', 10, true);


--
-- Name: visits_visit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.visits_visit_id_seq', 501, true);


--
-- Name: clinics clinics_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clinics
    ADD CONSTRAINT clinics_email_key UNIQUE (email);


--
-- Name: clinics clinics_phone_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clinics
    ADD CONSTRAINT clinics_phone_key UNIQUE (phone);


--
-- Name: clinics clinics_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clinics
    ADD CONSTRAINT clinics_pkey PRIMARY KEY (clinic_id);


--
-- Name: diagnoses diagnoses_icd_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.diagnoses
    ADD CONSTRAINT diagnoses_icd_code_key UNIQUE (icd_code);


--
-- Name: diagnoses diagnoses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.diagnoses
    ADD CONSTRAINT diagnoses_pkey PRIMARY KEY (diagnosis_id);


--
-- Name: medical_tests medical_tests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medical_tests
    ADD CONSTRAINT medical_tests_pkey PRIMARY KEY (test_id);


--
-- Name: medical_workers medical_workers_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medical_workers
    ADD CONSTRAINT medical_workers_email_key UNIQUE (email);


--
-- Name: medical_workers medical_workers_phone_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medical_workers
    ADD CONSTRAINT medical_workers_phone_key UNIQUE (phone);


--
-- Name: medical_workers medical_workers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medical_workers
    ADD CONSTRAINT medical_workers_pkey PRIMARY KEY (worker_id);


--
-- Name: patients patients_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_email_key UNIQUE (email);


--
-- Name: patients patients_phone_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_phone_key UNIQUE (phone);


--
-- Name: patients patients_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_pkey PRIMARY KEY (patient_id);


--
-- Name: patients patients_snils_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_snils_key UNIQUE (snils);


--
-- Name: prescriptions prescriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescriptions
    ADD CONSTRAINT prescriptions_pkey PRIMARY KEY (prescription_id);


--
-- Name: specializations specializations_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.specializations
    ADD CONSTRAINT specializations_name_key UNIQUE (name);


--
-- Name: specializations specializations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.specializations
    ADD CONSTRAINT specializations_pkey PRIMARY KEY (specialization_id);


--
-- Name: prescriptions unique_medication_per_visit; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescriptions
    ADD CONSTRAINT unique_medication_per_visit UNIQUE (visit_id, medication_name);


--
-- Name: patients unique_passport; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT unique_passport UNIQUE (passport_series, passport_number);


--
-- Name: visit_diagnoses visit_diagnoses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visit_diagnoses
    ADD CONSTRAINT visit_diagnoses_pkey PRIMARY KEY (visit_id, diagnosis_id);


--
-- Name: visits visits_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visits
    ADD CONSTRAINT visits_pkey PRIMARY KEY (visit_id);


--
-- Name: idx_patients_phone; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_patients_phone ON public.patients USING btree (phone);


--
-- Name: idx_prescriptions_visit_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_prescriptions_visit_id ON public.prescriptions USING btree (visit_id);


--
-- Name: idx_tests_visit_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tests_visit_id ON public.medical_tests USING btree (visit_id);


--
-- Name: idx_visits_patient_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_visits_patient_date ON public.visits USING btree (patient_id, visit_date);


--
-- Name: idx_visits_worker_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_visits_worker_date ON public.visits USING btree (worker_id, visit_date);


--
-- Name: visits trg_check_visit_overlap; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_visit_overlap BEFORE INSERT OR UPDATE ON public.visits FOR EACH ROW EXECUTE FUNCTION public.check_visit_overlap();


--
-- Name: medical_tests medical_tests_visit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medical_tests
    ADD CONSTRAINT medical_tests_visit_id_fkey FOREIGN KEY (visit_id) REFERENCES public.visits(visit_id) ON DELETE CASCADE;


--
-- Name: medical_workers medical_workers_clinic_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medical_workers
    ADD CONSTRAINT medical_workers_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES public.clinics(clinic_id) ON DELETE CASCADE;


--
-- Name: medical_workers medical_workers_specialization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medical_workers
    ADD CONSTRAINT medical_workers_specialization_id_fkey FOREIGN KEY (specialization_id) REFERENCES public.specializations(specialization_id);


--
-- Name: prescriptions prescriptions_visit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescriptions
    ADD CONSTRAINT prescriptions_visit_id_fkey FOREIGN KEY (visit_id) REFERENCES public.visits(visit_id) ON DELETE CASCADE;


--
-- Name: visit_diagnoses visit_diagnoses_diagnosis_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visit_diagnoses
    ADD CONSTRAINT visit_diagnoses_diagnosis_id_fkey FOREIGN KEY (diagnosis_id) REFERENCES public.diagnoses(diagnosis_id);


--
-- Name: visit_diagnoses visit_diagnoses_visit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visit_diagnoses
    ADD CONSTRAINT visit_diagnoses_visit_id_fkey FOREIGN KEY (visit_id) REFERENCES public.visits(visit_id) ON DELETE CASCADE;


--
-- Name: visits visits_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visits
    ADD CONSTRAINT visits_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(patient_id) ON DELETE CASCADE;


--
-- Name: visits visits_worker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visits
    ADD CONSTRAINT visits_worker_id_fkey FOREIGN KEY (worker_id) REFERENCES public.medical_workers(worker_id);


--
-- PostgreSQL database dump complete
--

