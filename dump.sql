--
-- PostgreSQL database dump
--

-- Dumped from database version 14.5
-- Dumped by pg_dump version 14.5

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: myschema; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA myschema;


ALTER SCHEMA myschema OWNER TO postgres;

--
-- Name: categoria; Type: DOMAIN; Schema: myschema; Owner: postgres
--

CREATE DOMAIN myschema.categoria AS character varying(100)
	CONSTRAINT categoria_check CHECK ((((VALUE)::text = 'Junior'::text) OR ((VALUE)::text = 'Middle'::text) OR ((VALUE)::text = 'Senior'::text) OR ((VALUE)::text = 'Dirigente'::text)));


ALTER DOMAIN myschema.categoria OWNER TO postgres;

--
-- Name: percentuale; Type: DOMAIN; Schema: myschema; Owner: postgres
--

CREATE DOMAIN myschema.percentuale AS double precision
	CONSTRAINT percentuale_check CHECK (((VALUE >= (0)::double precision) AND (VALUE <= (1)::double precision)));


ALTER DOMAIN myschema.percentuale OWNER TO postgres;

--
-- Name: tipo_c; Type: DOMAIN; Schema: myschema; Owner: postgres
--

CREATE DOMAIN myschema.tipo_c AS character varying(100)
	CONSTRAINT tipo_c_check CHECK ((((VALUE)::text = 'Indeterminato'::text) OR ((VALUE)::text = 'Determinato'::text)));


ALTER DOMAIN myschema.tipo_c OWNER TO postgres;

--
-- Name: anni_lavoro(character); Type: FUNCTION; Schema: myschema; Owner: postgres
--

CREATE FUNCTION myschema.anni_lavoro(codicef character) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
DataPrimaAssunzione Carriera.PrimaAssunzione%TYPE;
anni INTEGER;
BEGIN
--Prelevo la data di prima assunzione del dipendente
SELECT C1.PrimaAssunzione INTO DataPrimaAssunzione
FROM (DIPENDENTE AS D JOIN POSSESSIONE AS P1 ON D.CF=P1.CF) JOIN CARRIERA AS C1 ON P1.IDCARRIERA=C1.IDCARRIERA
WHERE D.CF=CODICEF;
--Calcolo gli anni di lavoro
anni:=EXTRACT(YEARS FROM age(CURRENT_DATE, DataPrimaAssunzione));
RAISE NOTICE 'Il dipendente % ha lavorato per % anni' , CODICEF, anni;
return anni;
END;
$$;


ALTER FUNCTION myschema.anni_lavoro(codicef character) OWNER TO postgres;

--
-- Name: anzianita(character); Type: FUNCTION; Schema: myschema; Owner: postgres
--

CREATE FUNCTION myschema.anzianita(codicef character) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
passaggio BOOLEAN:=false;
anni_Carriera INTEGER;
MyRuolo Dipendente.Ruolo%TYPE;
BEGIN
--Prelevo il ruolo del dipendente
SELECT D.RUOLO INTO MyRuolo
FROM DIPENDENTE AS D
WHERE D.CF=CODICEF;
--Calcolo gli anni di lavoro di quel dipendente attraverso la funzione Anni_Lavoro
SELECT Anni_Lavoro(CODICEF) INTO anni_Carriera;
--Se gli anni sono compresi tra 3 e 7 escluso allora effettuo il passaggio a middle
IF (anni_Carriera>=3 AND anni_Carriera<7) THEN
--Se il ruolo è già middle non c'è bisogno di effettuare il passaggio
    IF(MyRuolo = 'Junior') THEN
    passaggio=passaggio_middle(CODICEF);
    END IF;
--Se gli anni sono maggiori di 7 compreso allora effettuo il passaggio a senior
ELSEIF (anni_Carriera>=7) THEN
--Se il ruolo è già senior non c'è bisogno di effettuale il passaggio
    IF(MyRuolo = 'Middle') THEN
    passaggio=passaggio_senior(CODICEF);
    --Se non ho avuto per qualche errore il passaggio di promozione prima dei 7 anni 
    --e sono Junior ora effettuo il passaggio prima a middle e poi a senior
    ELSIF(MyRuolo = 'Junior') THEN
    passaggio=passaggio_middle(CODICEF);
    passaggio=passaggio_senior(CODICEF);
    END IF;
END IF;
return passaggio;
END;
$$;


ALTER FUNCTION myschema.anzianita(codicef character) OWNER TO postgres;

--
-- Name: aumento_stipendio(character, double precision); Type: FUNCTION; Schema: myschema; Owner: postgres
--

CREATE FUNCTION myschema.aumento_stipendio(codicef character, valore double precision) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
MyStip carriera.StipendioCorrente%TYPE;
MaxPromozione carriera.IDCARRIERA%TYPE;
PrimaA carriera.PrimaAssunzione%TYPE;
MaximumC carriera.IDCarriera%TYPE;
ora TIMESTAMP;
BEGIN
--Prelevo l'ultima promozione
SELECT MAX(C1.IDCARRIERA) INTO MaxPromozione
FROM CARRIERA AS C1 JOIN POSSESSIONE AS P1 ON C1.IDCARRIERA=P1.IDCARRIERA
WHERE P1.CF=CODICEF;
--Prelevo l'ultimo stipendio
SELECT C1.StipendioCorrente, C1.PrimaAssunzione INTO MyStip,PrimaA
FROM (CARRIERA AS C1 JOIN POSSESSIONE AS P1 ON C1.IDCARRIERA=P1.IDCARRIERA) 
WHERE P1.CF=CODICEF AND C1.IDCARRIERA=MaxPromozione;
--Inserisco una nuova carriera
ora=now();
INSERT INTO CARRIERA(PrimaAssunzione,DataPromozione,AumentoStipendio,RuoloPrecedente,StipendioPrecedente, StipendioCorrente)
(SELECT PrimaA, ora, valore, D.Ruolo, MyStip, (MyStip*valore)+MyStip
FROM DIPENDENTE AS D
WHERE D.CF=CODICEF);
--Prendo l'ultima carriera inserita
SELECT MAX(C1.IDCARRIERA) INTO MaximumC
FROM CARRIERA AS C1;
--Inserisco una nuova tupla in possessione
INSERT INTO POSSESSIONE(IDCarriera,CF)
VALUES(MaximumC,CODICEF);
return true;
END;
$$;


ALTER FUNCTION myschema.aumento_stipendio(codicef character, valore double precision) OWNER TO postgres;

--
-- Name: check_for_global_promotion(character varying, character varying); Type: PROCEDURE; Schema: myschema; Owner: postgres
--

CREATE PROCEDURE myschema.check_for_global_promotion(IN nome character varying, IN via character varying)
    LANGUAGE plpgsql
    AS $_$
DECLARE
--Scrivo il comando per prelevare ogni codice fiscale di dipendenti di una certa azienda
comandoSQL VARCHAR(1000):='SELECT A.CF
                           FROM ASSUNZIONE AS A
						   WHERE A.VIA=$1 AND A.NOME=$2';
cursore REFCURSOR;
CODICEF Dipendente.CF%TYPE;
BEGIN
--apro il cursore utilizzando i parametri di ingresso
OPEN cursore FOR EXECUTE comandoSQL using via, nome;
LOOP
--prelevo il codice fiscale fin quando finiscono i dipendenti
FETCH cursore INTO CODICEF;
EXIT WHEN NOT FOUND;
--chiamo la funzione Check_For_Promotion
call Check_For_Promotion(CODICEF);
END LOOP;
CLOSE cursore;
END;
$_$;


ALTER PROCEDURE myschema.check_for_global_promotion(IN nome character varying, IN via character varying) OWNER TO postgres;

--
-- Name: check_for_global_renewal(character varying, character varying); Type: PROCEDURE; Schema: myschema; Owner: postgres
--

CREATE PROCEDURE myschema.check_for_global_renewal(IN nome character varying, IN via character varying)
    LANGUAGE plpgsql
    AS $_$
DECLARE
--Scrivo il comando per prelevare ogni codice fiscale di dipendenti di una certa azienda
comandoSQL VARCHAR(1000):='SELECT A.CF
                           FROM ASSUNZIONE AS A
						   WHERE A.VIA=$1 AND A.NOME=$2';
cursore REFCURSOR;
CODICEF Dipendente.CF%TYPE;
BEGIN
--apro il cursore utilizzando i parametri di ingresso
OPEN cursore FOR EXECUTE comandoSQL using via, nome;
LOOP
--prelevo il codice fiscale fin quando finiscono i dipendenti
FETCH cursore INTO CODICEF;
EXIT WHEN NOT FOUND;
--chiamo la funzione Check_For_Promotion
perform Renewal_Contract(CODICEF);
END LOOP;
CLOSE cursore;
END;
$_$;


ALTER PROCEDURE myschema.check_for_global_renewal(IN nome character varying, IN via character varying) OWNER TO postgres;

--
-- Name: check_for_promotion(character); Type: PROCEDURE; Schema: myschema; Owner: postgres
--

CREATE PROCEDURE myschema.check_for_promotion(IN codicef character)
    LANGUAGE plpgsql
    AS $$
DECLARE
passaggio BOOLEAN;
BEGIN
RAISE NOTICE 'Controllo se il dipendente % è idoneo al passaggio di ruolo', CODICEF;
--Utilizzo la funzione Anzianita
SELECT Anzianita(CODICEF) INTO passaggio;
IF(passaggio)THEN
RAISE NOTICE 'Passaggio di ruolo effettuato.';
ELSE RAISE NOTICE 'Passaggio di ruolo non effettuato.';
END IF;
END;
$$;


ALTER PROCEDURE myschema.check_for_promotion(IN codicef character) OWNER TO postgres;

--
-- Name: chiama_aumento_stipendio(character, double precision); Type: PROCEDURE; Schema: myschema; Owner: postgres
--

CREATE PROCEDURE myschema.chiama_aumento_stipendio(IN codicef character, IN valore double precision)
    LANGUAGE plpgsql
    AS $$
DECLARE
aumentato BOOLEAN;
BEGIN
RAISE NOTICE 'Aumento lo stipendio del dipendente % in percentuale %', CODICEF, valore;
SELECT Aumento_Stipendio(CODICEF,valore) INTO aumentato;
IF(aumentato) THEN
RAISE NOTICE 'Lo stipendio è stato aumentato.';
ELSE RAISE NOTICE 'Lo stipendio non è stato aumentato.';
END IF;
END;
$$;


ALTER PROCEDURE myschema.chiama_aumento_stipendio(IN codicef character, IN valore double precision) OWNER TO postgres;

--
-- Name: chiamata_trigger_gestione_laboratorio(); Type: FUNCTION; Schema: myschema; Owner: postgres
--

CREATE FUNCTION myschema.chiamata_trigger_gestione_laboratorio() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
MyRuolo Dipendente.Ruolo%TYPE;
BEGIN
--Prelevo il ruolo del dipendente che sto inserendo in gestione
SELECT D.Ruolo INTO MyRuolo
FROM DIPENDENTE AS D
WHERE New.CF=D.CF;
--Se il ruolo non è Senior non va bene
IF(MyRuolo!='Senior') THEN
RAISE EXCEPTION 'Chi gestisce il laboratrio non è un dipendente Senior.';
END IF;
return new;
END;
$$;


ALTER FUNCTION myschema.chiamata_trigger_gestione_laboratorio() OWNER TO postgres;

--
-- Name: chiamata_trigger_indeterminato_senza_scadenza(); Type: FUNCTION; Schema: myschema; Owner: postgres
--

CREATE FUNCTION myschema.chiamata_trigger_indeterminato_senza_scadenza() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
IF ((new.Tipo='Indeterminato' AND new.ScadenzaContratto IS NULL) OR 
(new.Tipo='Determinato' AND new.ScadenzaContratto IS NOT NULL)) THEN --ciò che va bene
RETURN NEW;
ELSIF ((new.Tipo='Determinato' AND new.ScadenzaContratto IS NULL) OR 
(new.Tipo='Indeterminato' AND new.ScadenzaContratto IS NOT NULL)) THEN --ciò che non va bene
RAISE EXCEPTION 'Vincolo tipo-scadenza contratto non rispettato.';
RETURN NULL;
END IF;
END;
$$;


ALTER FUNCTION myschema.chiamata_trigger_indeterminato_senza_scadenza() OWNER TO postgres;

--
-- Name: chiamata_trigger_referenza_progetti(); Type: FUNCTION; Schema: myschema; Owner: postgres
--

CREATE FUNCTION myschema.chiamata_trigger_referenza_progetti() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
MyRuolo Dipendente.Ruolo%TYPE;
BEGIN
--Prelevo il ruolo del dipendente che sto inserendo in referenza
SELECT D.Ruolo INTO MyRuolo
FROM DIPENDENTE AS D
WHERE New.CF=D.CF;
--Se in ruolo non è Senio non va bene
IF(MyRuolo!='Senior') THEN
RAISE EXCEPTION 'Il referente del progetto non è un dipendente Senior.';
END IF;
return new;
END;
$$;


ALTER FUNCTION myschema.chiamata_trigger_referenza_progetti() OWNER TO postgres;

--
-- Name: chiamata_trigger_reponsabilita_progetti(); Type: FUNCTION; Schema: myschema; Owner: postgres
--

CREATE FUNCTION myschema.chiamata_trigger_reponsabilita_progetti() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
MyRuolo Dipendente.Ruolo%TYPE;
BEGIN
--Prelevo il ruolo del dipendente che sto inserendo in responsabilità
SELECT D.Ruolo INTO MyRuolo
FROM DIPENDENTE AS D
WHERE New.CF=D.CF;
--Se il ruolo non è Dirigente non va bene
IF(MyRuolo!='Dirigente') THEN
RAISE EXCEPTION 'Il responsabile non è un Dirigente.';
END IF;
return new;
END;
$$;


ALTER FUNCTION myschema.chiamata_trigger_reponsabilita_progetti() OWNER TO postgres;

--
-- Name: chiamata_trigger_utilizzo_laboratori(); Type: FUNCTION; Schema: myschema; Owner: postgres
--

CREATE FUNCTION myschema.chiamata_trigger_utilizzo_laboratori() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
numero_laboratori INTEGER;
BEGIN
--Conto il numero di laboratori che sono utilizzati dal progetto
SELECT COUNT(U.TOPIC) INTO numero_laboratori
FROM UTILIZZO AS U
WHERE New.CUP=U.CUP;
--Se il numero di laboratori è già 3 allora non va bene
IF (numero_laboratori=3) THEN
RAISE EXCEPTION 'Il progetto lavora già su 3 laboratori.';
RETURN NULL;
ELSIF (numero_laboratori<3) THEN
return new;
END IF;
END;
$$;


ALTER FUNCTION myschema.chiamata_trigger_utilizzo_laboratori() OWNER TO postgres;

--
-- Name: consistenza_prima_assunzione(); Type: FUNCTION; Schema: myschema; Owner: postgres
--

CREATE FUNCTION myschema.consistenza_prima_assunzione() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
MyFirma Contratto.DataFirma%TYPE;
MyAssunzione Carriera.PrimaAssunzione%TYPE;
BEGIN
--Prelevo la data del primo contratto firmato dal dipendente
SELECT MIN(C1.DataFirma) INTO MyFirma
FROM CONTRATTO AS C1 JOIN DIPENDENTE AS D ON C1.CF=D.CF;
--Prelevo la prima assunzione della carriera che sto inserendo
SELECT C3.PrimaAssunzione INTO MyAssunzione
FROM CARRIERA AS C3
WHERE C3.IDCARRIERA=NEW.IDCARRIERA;
--Se le due date non coincidono non va bene
IF MyFirma!=MyAssunzione THEN
RAISE EXCEPTION 'La data di prima assunzione non coincide con la data di firma del primo contratto.';
END IF;
return new;
END;
$$;


ALTER FUNCTION myschema.consistenza_prima_assunzione() OWNER TO postgres;

--
-- Name: generate_contract(); Type: FUNCTION; Schema: myschema; Owner: postgres
--

CREATE FUNCTION myschema.generate_contract() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
MyID Carriera.IDCARRIERA%TYPE;
MyRuolo Dipendente.Ruolo%TYPE;
BEGIN
--Prelevo il ruolo del dipendente che sto assumendo
SELECT D.Ruolo INTO MyRuolo
FROM DIPENDENTE AS D
WHERE New.CF=D.CF;
--Inserisco il nuovo contratto e la carriera del dipendente in base al ruolo, 
--per motivi di prova dei trigger correttamente decido di inserire 
--il primo contratto il 2016-01-01 come se fosse la mia data corrente, 
--mentre la scadenza è la mia data corrente
IF(MyRuolo='Junior') THEN
INSERT INTO CONTRATTO(tipo,datafirma,scadenzacontratto,stipendio,cf)
VALUES ('Determinato','2016-01-01',current_date,1100,New.CF);
INSERT INTO CARRIERA(primaassunzione,datapromozione,ruoloprecedente,
aumentostipendio,stipendiocorrente,stipendioprecedente)
VALUES ('2016-01-01',NULL,NULL,NULL,1100,NULL); 

ELSIF (MyRuolo='Middle') THEN
INSERT INTO CONTRATTO(tipo,datafirma,scadenzacontratto,stipendio,cf)
VALUES ('Determinato','2016-01-01',current_date,1210,New.CF);
INSERT INTO CARRIERA(primaassunzione,datapromozione,ruoloprecedente,
aumentostipendio,stipendiocorrente,stipendioprecedente)
VALUES ('2016-01-01',NULL,'Junior',NULL,1210,NULL); 

ELSIF (MyRuolo='Senior') THEN
INSERT INTO CONTRATTO(tipo,datafirma,scadenzacontratto,stipendio,cf)
VALUES ('Determinato','2016-01-01',current_date,1452,New.CF);
INSERT INTO CARRIERA(primaassunzione,datapromozione,ruoloprecedente,
aumentostipendio,stipendiocorrente,stipendioprecedente)
VALUES ('2016-01-01',NULL,'Middle',NULL,1452,NULL); 

ELSIF (MyRuolo='Dirigente') THEN
INSERT INTO CONTRATTO(tipo,datafirma,scadenzacontratto,stipendio,cf)
VALUES ('Determinato','2016-01-01',current_date,1815,New.CF);
INSERT INTO CARRIERA(primaassunzione,datapromozione,ruoloprecedente,
aumentostipendio,stipendiocorrente,stipendioprecedente)
VALUES ('2016-01-01',NULL,NULL,NULL,1815,NULL);

END IF;
--Prendiamo l'id dell'ultima carriera inserita
SELECT MAX(C1.IDCARRIERA) INTO MyID
FROM CARRIERA AS C1;
--Inserisco quest'ultima carriera nella tupla di possessione del dipendente
INSERT INTO POSSESSIONE(IDCarriera,CF)
VALUES (MyID,New.CF);
RETURN NEW;
END;
$$;


ALTER FUNCTION myschema.generate_contract() OWNER TO postgres;

--
-- Name: isobsolete(character); Type: FUNCTION; Schema: myschema; Owner: postgres
--

CREATE FUNCTION myschema.isobsolete(codicef character) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
LastContract Contratto.IDContratto%TYPE;
MaxFirma Contratto.DataFirma%TYPE;
MyScadenza Contratto.ScadenzaContratto%TYPE;
BEGIN
--Prendiamo il contratto più recente del dipendente
SELECT MAX(C1.DataFirma) INTO MaxFirma
FROM CONTRATTO AS C1
WHERE C1.CF=CODICEF;
--Prendiamo l'id del contratto e la scadenza del contratto con firma più recente
SELECT C1.IDContratto,C1.ScadenzaContratto INTO LastContract, MyScadenza
FROM CONTRATTO AS C1
WHERE C1.CF=CODICEF AND C1.DATAFIRMA=MaxFirma
GROUP BY C1.IDContratto;
--Se il contratto è scaduto allora IsObsolete è vera
IF('now'>MyScadenza) THEN
RETURN TRUE;
END IF;
RETURN FALSE;
END;
$$;


ALTER FUNCTION myschema.isobsolete(codicef character) OWNER TO postgres;

--
-- Name: passaggio_dirigente(character); Type: FUNCTION; Schema: myschema; Owner: postgres
--

CREATE FUNCTION myschema.passaggio_dirigente(codicef character) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
MyID Carriera.IDCarriera%TYPE;
UltimaPromozione Carriera.IDCarriera%TYPE;
MyStip carriera.StipendioCorrente%TYPE;
PrimaA carriera.PrimaAssunzione%TYPE;
ora TIMESTAMP;
BEGIN
--Richiamo la procedura chiama_aumento_stipendio
call chiama_aumento_stipendio(CODICEF,0.25); --E' una decisione aziendale che per il passaggio a Dirigente lo stipendio viene aumentato del 25%
--Faccio l'update del ruolo del dipendente
UPDATE DIPENDENTE AS D
SET RUOLO='Dirigente'
WHERE D.CF=CODICEF;
return true;
END;
$$;


ALTER FUNCTION myschema.passaggio_dirigente(codicef character) OWNER TO postgres;

--
-- Name: passaggio_middle(character); Type: FUNCTION; Schema: myschema; Owner: postgres
--

CREATE FUNCTION myschema.passaggio_middle(codicef character) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
BEGIN
--Richiamo la procedura chiama_aumento_stipendio
call chiama_aumento_stipendio(CODICEF,0.1); --E' una decisione aziendale che per il passaggio a Middle lo stipendio viene aumentato del 10%
--Faccio l'update del ruolo del dipendente
UPDATE DIPENDENTE AS D
SET RUOLO='Middle'
WHERE D.CF=CODICEF;
return true;
END;
$$;


ALTER FUNCTION myschema.passaggio_middle(codicef character) OWNER TO postgres;

--
-- Name: passaggio_senior(character); Type: FUNCTION; Schema: myschema; Owner: postgres
--

CREATE FUNCTION myschema.passaggio_senior(codicef character) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
BEGIN
--Richiamo la procedura chiama_aumento_stipendio
call chiama_aumento_stipendio(CODICEF,0.2); --E' una decisione aziendale che per il passaggio a Senior lo stipendio viene aumentato del 20%
--Faccio l'update del ruolo del dipendente
UPDATE DIPENDENTE AS D
SET RUOLO='Senior'
WHERE D.CF=CODICEF;
return true;
END;
$$;


ALTER FUNCTION myschema.passaggio_senior(codicef character) OWNER TO postgres;

--
-- Name: renewal_contract(character); Type: FUNCTION; Schema: myschema; Owner: postgres
--

CREATE FUNCTION myschema.renewal_contract(codicef character) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
MyType Dipendente.Ruolo%TYPE;
MyStip Carriera.StipendioCorrente%TYPE;
MaxPromozione Carriera.IDCARRIERA%TYPE;
BEGIN
--Prendo la data di promozione più recente del dipendente per poter icavare lo stipendio corrente da inserire nel nuovo contratto
SELECT MAX(C1.IDCARRIERA) INTO MaxPromozione
FROM CARRIERA AS C1 JOIN POSSESSIONE AS P1 ON C1.IDCARRIERA=P1.IDCARRIERA
WHERE P1.CF=CODICEF;
--Prendo lo stipendio corrente dall'ultima promozione
SELECT C1.StipendioCorrente INTO MyStip
FROM (DIPENDENTE AS D JOIN POSSESSIONE AS P1 ON D.CF=P1.CF) JOIN CARRIERA AS C1 ON C1.IDCARRIERA=P1.IDCARRIERA
WHERE D.CF=CODICEF AND C1.IDCARRIERA=MaxPromozione;
--Se IsObsolete è vera allora inserisco un nuovo contratto, per scelta aziendale un contratto a tempo determinato scade ogni 3 anni
IF(IsObsolete(CODICEF)) THEN
INSERT INTO CONTRATTO(tipo,DataFirma,ScadenzaContratto,Stipendio,CF)
VALUES('Determinato','now',current_date+1095, MyStip, CODICEF);
RAISE NOTICE 'Rinnovo contratto di % effettuato correttamente.', CODICEF;
RETURN TRUE;
END IF;
RAISE NOTICE 'Non occorre rinnovare il contratto.';
RETURN FALSE;
END;
$$;


ALTER FUNCTION myschema.renewal_contract(codicef character) OWNER TO postgres;

--
-- Name: toindeterminate(character); Type: FUNCTION; Schema: myschema; Owner: postgres
--

CREATE FUNCTION myschema.toindeterminate(codicef character) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
LastContract Contratto.IDContratto%TYPE;
MaxFirma Contratto.DataFirma%TYPE;
MyScadenza Contratto.ScadenzaContratto%TYPE;
MyStip Carriera.StipendioCorrente%TYPE;
MaxPromozione Carriera.IDCARRIERA%TYPE;
BEGIN
--Prendiamo il contratto più recente del dipendente
SELECT MAX(C1.DataFirma) INTO MaxFirma
FROM CONTRATTO AS C1
WHERE C1.CF=CODICEF;
--Prendiamo l'id del contratto e la scadenza del contratto con firma più recente
SELECT C1.IDContratto,C1.ScadenzaContratto INTO LastContract, MyScadenza
FROM CONTRATTO AS C1
WHERE C1.CF=CODICEF AND C1.DATAFIRMA=MaxFirma
GROUP BY C1.IDContratto;
--Se il dipendente possiede già un contratto a tempo indeterminato non devo fare niente
IF(MyScadenza IS NULL) THEN
    RAISE NOTICE 'IL DIPENDENTE % POSSIEDE GIA UN CONTRATTO A TEMPO INDETERMINATO', CODICEF;
    RETURN FALSE;
ELSE
    --Prendo la data di promozione più recente del dipendente per poter ricavare lo stipendio corrente da inserire nel nuovo contratto
    SELECT MAX(C1.IDCARRIERA) INTO MaxPromozione
    FROM CARRIERA AS C1 JOIN POSSESSIONE AS P1 ON C1.IDCARRIERA=P1.IDCARRIERA
    WHERE P1.CF=CODICEF;
    --Prendo lo stipendio corrente dall'ultima promozione
    SELECT C1.StipendioCorrente INTO MyStip
    FROM (DIPENDENTE AS D JOIN POSSESSIONE AS P1 ON D.CF=P1.CF) JOIN CARRIERA AS C1 ON C1.IDCARRIERA=P1.IDCARRIERA
    WHERE D.CF=CODICEF AND C1.IDCARRIERA=MaxPromozione;
    --Inserisco il nuovo contratto
    INSERT INTO CONTRATTO(Tipo,DataFirma,ScadenzaContratto,Stipendio,CF)
    VALUES('Indeterminato','now',NULL,MyStip,CODICEF);
    RETURN TRUE;
END IF;
END;
$$;


ALTER FUNCTION myschema.toindeterminate(codicef character) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: afferenza; Type: TABLE; Schema: myschema; Owner: postgres
--

CREATE TABLE myschema.afferenza (
    cf character(16),
    topic character varying(100),
    edificio character varying(100),
    stanza character varying(100)
);


ALTER TABLE myschema.afferenza OWNER TO postgres;

--
-- Name: assunzione; Type: TABLE; Schema: myschema; Owner: postgres
--

CREATE TABLE myschema.assunzione (
    nome character varying(100),
    via character varying(100),
    cf character(16)
);


ALTER TABLE myschema.assunzione OWNER TO postgres;

--
-- Name: azienda; Type: TABLE; Schema: myschema; Owner: postgres
--

CREATE TABLE myschema.azienda (
    nome character varying(100) NOT NULL,
    titolare character varying(100),
    via character varying(100) NOT NULL,
    civico character varying(100),
    cap character varying(100),
    fatturato double precision,
    CONSTRAINT validita_nome_azienda CHECK ((((nome)::text ~ '[a-z]'::text) OR ((nome)::text ~ '[A-Z]'::text) OR ((nome)::text ~ '[0-9]'::text))),
    CONSTRAINT validita_titolare CHECK ((((titolare)::text ~ '[a-z]'::text) OR ((titolare)::text ~ '[A-Z]'::text)))
);


ALTER TABLE myschema.azienda OWNER TO postgres;

--
-- Name: carriera; Type: TABLE; Schema: myschema; Owner: postgres
--

CREATE TABLE myschema.carriera (
    idcarriera integer NOT NULL,
    primaassunzione timestamp without time zone,
    datapromozione timestamp without time zone,
    ruoloprecedente myschema.categoria,
    aumentostipendio myschema.percentuale,
    stipendiocorrente double precision,
    stipendioprecedente double precision,
    CONSTRAINT validita_data_carriera CHECK ((datapromozione >= primaassunzione))
);


ALTER TABLE myschema.carriera OWNER TO postgres;

--
-- Name: carriera_idcarriera_seq; Type: SEQUENCE; Schema: myschema; Owner: postgres
--

CREATE SEQUENCE myschema.carriera_idcarriera_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE myschema.carriera_idcarriera_seq OWNER TO postgres;

--
-- Name: carriera_idcarriera_seq; Type: SEQUENCE OWNED BY; Schema: myschema; Owner: postgres
--

ALTER SEQUENCE myschema.carriera_idcarriera_seq OWNED BY myschema.carriera.idcarriera;


--
-- Name: contratto; Type: TABLE; Schema: myschema; Owner: postgres
--

CREATE TABLE myschema.contratto (
    idcontratto integer NOT NULL,
    tipo myschema.tipo_c,
    datafirma timestamp without time zone,
    scadenzacontratto timestamp without time zone,
    stipendio double precision,
    cf character(16),
    CONSTRAINT validita_data_contratto CHECK ((scadenzacontratto > datafirma))
);


ALTER TABLE myschema.contratto OWNER TO postgres;

--
-- Name: possessione; Type: TABLE; Schema: myschema; Owner: postgres
--

CREATE TABLE myschema.possessione (
    idcarriera integer,
    cf character(16)
);


ALTER TABLE myschema.possessione OWNER TO postgres;

--
-- Name: carrieraconcontratto; Type: VIEW; Schema: myschema; Owner: postgres
--

CREATE VIEW myschema.carrieraconcontratto AS
 SELECT p1.cf,
    c1.datapromozione AS datapromozionecarriera,
    c1.stipendiocorrente AS ultimostipendio,
    c2.datafirma AS datafirmacontratto,
    c2.tipo AS tipocontratto,
    c2.scadenzacontratto
   FROM ((myschema.carriera c1
     JOIN myschema.possessione p1 ON ((c1.idcarriera = p1.idcarriera)))
     JOIN myschema.contratto c2 ON ((c2.cf = p1.cf)))
  GROUP BY p1.cf, c1.datapromozione, c1.stipendiocorrente, c2.datafirma, c2.tipo, c2.scadenzacontratto
  ORDER BY c1.datapromozione DESC;


ALTER TABLE myschema.carrieraconcontratto OWNER TO postgres;

--
-- Name: contratto_idcontratto_seq; Type: SEQUENCE; Schema: myschema; Owner: postgres
--

CREATE SEQUENCE myschema.contratto_idcontratto_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE myschema.contratto_idcontratto_seq OWNER TO postgres;

--
-- Name: contratto_idcontratto_seq; Type: SEQUENCE OWNED BY; Schema: myschema; Owner: postgres
--

ALTER SEQUENCE myschema.contratto_idcontratto_seq OWNED BY myschema.contratto.idcontratto;


--
-- Name: dipendente; Type: TABLE; Schema: myschema; Owner: postgres
--

CREATE TABLE myschema.dipendente (
    nome character varying(100),
    cognome character varying(100),
    cf character(16) NOT NULL,
    specializzazione character varying(150),
    ruolo myschema.categoria,
    ufficio character varying(100),
    mansione character varying(200),
    CONSTRAINT validita_cf CHECK ((((cf ~ '[A-Z]'::text) OR (cf ~ '[0-9]'::text)) AND (char_length(cf) = 16))),
    CONSTRAINT validita_cognome CHECK ((((cognome)::text ~ '[A-Z]'::text) OR ((cognome)::text ~ '[a-z]'::text))),
    CONSTRAINT validita_nome CHECK ((((nome)::text ~ '[A-Z]'::text) OR ((nome)::text ~ '[a-z]'::text)))
);


ALTER TABLE myschema.dipendente OWNER TO postgres;

--
-- Name: finanziamento; Type: TABLE; Schema: myschema; Owner: postgres
--

CREATE TABLE myschema.finanziamento (
    nome character varying(100),
    via character varying(100),
    cup character varying(100)
);


ALTER TABLE myschema.finanziamento OWNER TO postgres;

--
-- Name: gestione; Type: TABLE; Schema: myschema; Owner: postgres
--

CREATE TABLE myschema.gestione (
    cf character(16),
    topic character varying(100),
    edificio character varying(100),
    stanza character varying(100)
);


ALTER TABLE myschema.gestione OWNER TO postgres;

--
-- Name: laboratorio; Type: TABLE; Schema: myschema; Owner: postgres
--

CREATE TABLE myschema.laboratorio (
    topic character varying(100) NOT NULL,
    edificio character varying(100) NOT NULL,
    stanza character varying(100) NOT NULL
);


ALTER TABLE myschema.laboratorio OWNER TO postgres;

--
-- Name: numero_afferenti_lab; Type: VIEW; Schema: myschema; Owner: postgres
--

CREATE VIEW myschema.numero_afferenti_lab AS
 SELECT afferenza.topic,
    afferenza.edificio,
    afferenza.stanza,
    count(afferenza.cf) AS num_aff
   FROM myschema.afferenza
  GROUP BY afferenza.topic, afferenza.edificio, afferenza.stanza;


ALTER TABLE myschema.numero_afferenti_lab OWNER TO postgres;

--
-- Name: numero_impiegati_aziendali; Type: VIEW; Schema: myschema; Owner: postgres
--

CREATE VIEW myschema.numero_impiegati_aziendali AS
 SELECT assunzione.nome,
    count(assunzione.cf) AS num_imp
   FROM myschema.assunzione
  GROUP BY assunzione.nome;


ALTER TABLE myschema.numero_impiegati_aziendali OWNER TO postgres;

--
-- Name: progetto; Type: TABLE; Schema: myschema; Owner: postgres
--

CREATE TABLE myschema.progetto (
    cup character varying(100) NOT NULL,
    nome character varying(100),
    budget double precision
);


ALTER TABLE myschema.progetto OWNER TO postgres;

--
-- Name: referenza; Type: TABLE; Schema: myschema; Owner: postgres
--

CREATE TABLE myschema.referenza (
    cf character(16),
    cup character varying(100)
);


ALTER TABLE myschema.referenza OWNER TO postgres;

--
-- Name: responsabilita; Type: TABLE; Schema: myschema; Owner: postgres
--

CREATE TABLE myschema.responsabilita (
    cf character(16),
    cup character varying(100)
);


ALTER TABLE myschema.responsabilita OWNER TO postgres;

--
-- Name: utilizzo; Type: TABLE; Schema: myschema; Owner: postgres
--

CREATE TABLE myschema.utilizzo (
    cup character varying(100),
    topic character varying(100),
    edificio character varying(100),
    stanza character varying(100)
);


ALTER TABLE myschema.utilizzo OWNER TO postgres;

--
-- Name: carriera idcarriera; Type: DEFAULT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.carriera ALTER COLUMN idcarriera SET DEFAULT nextval('myschema.carriera_idcarriera_seq'::regclass);


--
-- Name: contratto idcontratto; Type: DEFAULT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.contratto ALTER COLUMN idcontratto SET DEFAULT nextval('myschema.contratto_idcontratto_seq'::regclass);


--
-- Data for Name: afferenza; Type: TABLE DATA; Schema: myschema; Owner: postgres
--

COPY myschema.afferenza (cf, topic, edificio, stanza) FROM stdin;
F123456789012345	AI	Palazzo delle Scienze	A1
F234567890123456	Robotica	Palazzo delle Scienze	A2
F345678901234567	Chimica	Palazzo delle Tecnologie	C1
F456789012345678	Bioingegneria	Palazzo delle Tecnologie	C2
F567890123456789	Ingegneria Elettronica	Palazzo dell'Innovazione	D1
F678901234567890	Bioingegneria	Palazzo delle Tecnologie	C2
F789012345678901	AI	Palazzo delle Scienze	A1
F890123456789012	Fisica	Palazzo delle Scienze	B1
F901234567890123	Robotica	Palazzo delle Scienze	A2
F012345678901234	Fisica	Palazzo delle Scienze	B1
F123456789012346	Ingegneria Elettronica	Palazzo dell'Innovazione	D1
F234567890123457	AI	Palazzo delle Scienze	A1
\.


--
-- Data for Name: assunzione; Type: TABLE DATA; Schema: myschema; Owner: postgres
--

COPY myschema.assunzione (nome, via, cf) FROM stdin;
Walmart	Ave Hostos	F123456789012345
Walmart	Ave Hostos	F234567890123456
Walmart	Ave Hostos	F345678901234567
Walmart	Ave Hostos	F456789012345678
Walmart	Ave Hostos	F567890123456789
Walmart	Ave Hostos	F678901234567890
Walmart	Ave Hostos	F789012345678901
Walmart	Ave Hostos	F890123456789012
Walmart	Ave Hostos	F901234567890123
Walmart	Ave Hostos	F012345678901234
Walmart	Ave Hostos	F123456789012346
Walmart	Ave Hostos	F234567890123457
Walmart	Ave Hostos	F345678901234568
Walmart	Ave Hostos	F456789012345679
Walmart	Ave Hostos	F567890123456780
Walmart	Ave Hostos	F678901234567892
Walmart	Ave Hostos	F789012345678906
Spotify	Filippo Sassetti	ABCD1234EFGH5678
Spotify	Filippo Sassetti	LMNOPQRSTUVWXYZ1
Spotify	Filippo Sassetti	1234567890ABCDEF
Spotify	Filippo Sassetti	ABCDEFGHIJKLMNOP
Spotify	Filippo Sassetti	QRSTUVWXYZABCDEF
Spotify	Filippo Sassetti	GHIJKLMNOPQRSTU1
Spotify	Filippo Sassetti	WXYZABCDEFABCDEF
Spotify	Filippo Sassetti	BCDEFGHIJKLMNOPQ
Spotify	Filippo Sassetti	CDEFGHIJKLMNOPQR
Spotify	Filippo Sassetti	DEFGHIJKLMNOPQRS
Spotify	Filippo Sassetti	EFGHIJKLMNOPQRST
Spotify	Filippo Sassetti	FGHIJKLMNOPQRSTU
Spotify	Filippo Sassetti	GHIJKLMNOPQRSTUV
Spotify	Filippo Sassetti	HIJKLMNOPQRSTUVW
\.


--
-- Data for Name: azienda; Type: TABLE DATA; Schema: myschema; Owner: postgres
--

COPY myschema.azienda (nome, titolare, via, civico, cap, fatturato) FROM stdin;
Walmart	Carl Douglas McMillon	Ave Hostos	975	00680	1200000
Spotify	Daniel Ek	Filippo Sassetti	32	20124	2000000
\.


--
-- Data for Name: carriera; Type: TABLE DATA; Schema: myschema; Owner: postgres
--

COPY myschema.carriera (idcarriera, primaassunzione, datapromozione, ruoloprecedente, aumentostipendio, stipendiocorrente, stipendioprecedente) FROM stdin;
1	2016-01-01 00:00:00	\N	\N	\N	1100	\N
2	2016-01-01 00:00:00	\N	Middle	\N	1452	\N
3	2016-01-01 00:00:00	\N	\N	\N	1100	\N
4	2016-01-01 00:00:00	\N	Middle	\N	1452	\N
5	2016-01-01 00:00:00	\N	\N	\N	1100	\N
6	2016-01-01 00:00:00	\N	\N	\N	1815	\N
7	2016-01-01 00:00:00	\N	\N	\N	1815	\N
8	2016-01-01 00:00:00	\N	Middle	\N	1452	\N
9	2016-01-01 00:00:00	\N	Middle	\N	1452	\N
10	2016-01-01 00:00:00	\N	\N	\N	1100	\N
11	2016-01-01 00:00:00	\N	\N	\N	1100	\N
12	2016-01-01 00:00:00	\N	Junior	\N	1210	\N
13	2016-01-01 00:00:00	\N	Junior	\N	1210	\N
14	2016-01-01 00:00:00	\N	\N	\N	1100	\N
15	2016-01-01 00:00:00	\N	Junior	\N	1210	\N
16	2016-01-01 00:00:00	\N	\N	\N	1100	\N
17	2016-01-01 00:00:00	\N	\N	\N	1100	\N
18	2016-01-01 00:00:00	\N	Middle	\N	1452	\N
19	2016-01-01 00:00:00	\N	Middle	\N	1452	\N
20	2016-01-01 00:00:00	\N	Middle	\N	1452	\N
21	2016-01-01 00:00:00	\N	Junior	\N	1210	\N
22	2016-01-01 00:00:00	\N	Junior	\N	1210	\N
23	2016-01-01 00:00:00	\N	Junior	\N	1210	\N
24	2016-01-01 00:00:00	\N	Junior	\N	1210	\N
25	2016-01-01 00:00:00	\N	Junior	\N	1210	\N
26	2016-01-01 00:00:00	\N	\N	\N	1100	\N
27	2016-01-01 00:00:00	\N	\N	\N	1100	\N
28	2016-01-01 00:00:00	\N	\N	\N	1100	\N
29	2016-01-01 00:00:00	\N	\N	\N	1100	\N
30	2016-01-01 00:00:00	\N	\N	\N	1815	\N
31	2016-01-01 00:00:00	\N	\N	\N	1815	\N
\.


--
-- Data for Name: contratto; Type: TABLE DATA; Schema: myschema; Owner: postgres
--

COPY myschema.contratto (idcontratto, tipo, datafirma, scadenzacontratto, stipendio, cf) FROM stdin;
1	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1100	F123456789012345
2	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1452	F234567890123456
3	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1100	F345678901234567
4	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1452	F456789012345678
5	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1100	F567890123456789
6	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1815	F678901234567890
7	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1815	F789012345678901
8	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1452	F890123456789012
9	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1452	F901234567890123
10	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1100	F012345678901234
11	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1100	F123456789012346
12	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1210	F234567890123457
13	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1210	F345678901234568
14	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1100	F456789012345679
15	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1210	F567890123456780
16	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1100	F678901234567892
17	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1100	F789012345678906
18	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1452	ABCD1234EFGH5678
19	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1452	LMNOPQRSTUVWXYZ1
20	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1452	1234567890ABCDEF
21	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1210	ABCDEFGHIJKLMNOP
22	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1210	QRSTUVWXYZABCDEF
23	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1210	GHIJKLMNOPQRSTU1
24	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1210	WXYZABCDEFABCDEF
25	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1210	BCDEFGHIJKLMNOPQ
26	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1100	CDEFGHIJKLMNOPQR
27	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1100	DEFGHIJKLMNOPQRS
28	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1100	EFGHIJKLMNOPQRST
29	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1100	FGHIJKLMNOPQRSTU
30	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1815	GHIJKLMNOPQRSTUV
31	Determinato	2016-01-01 00:00:00	2023-01-22 00:00:00	1815	HIJKLMNOPQRSTUVW
\.


--
-- Data for Name: dipendente; Type: TABLE DATA; Schema: myschema; Owner: postgres
--

COPY myschema.dipendente (nome, cognome, cf, specializzazione, ruolo, ufficio, mansione) FROM stdin;
Mario	Rossi	F123456789012345	Informatica	Junior	IT	Settore IT
Luca	Bianchi	F234567890123456	Marketing	Senior	Marketing	Settore Marketing
Chiara	Verde	F345678901234567	Contabilità	Junior	Amministrazione	Settore Amministrativo
Giovanni	Nero	F456789012345678	Vendite	Senior	Vendite	Settore vendite
Simone	Grigio	F567890123456789	Risorse Umane	Junior	Risorse Umane	Settore Risorse Umane
Paola	Marrone	F678901234567890	Produzione	Dirigente	Produzione	Settore Produzione
Giuseppe	Giallo	F789012345678901	Design	Dirigente	Design	Settore design
Antonia	Arancione	F890123456789012	Sviluppo	Senior	Sviluppo	Settore Sviluppo
Edoardo	Rosso	F901234567890123	Qualità	Senior	Qualità	Settore Qualità
Francesca	Viola	F012345678901234	Progettazione	Junior	Progettazione	Settore Progettazione
Stefano	Blu	F123456789012346	Rapporti Pubblici	Junior	Rapporti Pubblici	Settore rapporti pubblici
Elisa	Verde	F234567890123457	Sicurezza	Middle	Sicurezza	Settore Sicurezza
Alessio	Giallo	F345678901234568	Acquisti	Middle	Acquisti	Settore Acquisti
Eleonora	Bianco	F456789012345679	Stampa	Junior	Stampa	Settore Stampa
Giorgia	Nero	F567890123456780	Innovazione	Middle	Innovazione	Settore Innovazione
Ginevra	Grigio	F678901234567892	Sviluppo Prodotto	Junior	Sviluppo Prodotto	Settore Sviluppo Prodotto
Lorenzo	Marrone	F789012345678906	Comunicazione	Junior	Comunicazione	Settore Comunicazione
Mario	Rossi	ABCD1234EFGH5678	Informatica	Senior	Marketing	Responsabile del team
Luca	Bianchi	LMNOPQRSTUVWXYZ1	Gestione delle risorse umane	Senior	Amministrazione	Gestione del personale
Paolo	Verdi	1234567890ABCDEF	Finanza	Senior	Finanza	Gestione del budget
Chiara	Gialli	ABCDEFGHIJKLMNOP	Marketing	Middle	Marketing	Sviluppo delle campagne pubblicitarie
Giovanni	Blu	QRSTUVWXYZABCDEF	Sviluppo software	Middle	Informatica	Sviluppo di nuove funzionalità
Roberta	Viola	GHIJKLMNOPQRSTU1	Gestione dei progetti	Middle	IT	Coordinamento del team di progetto
Andrea	Arancioni	WXYZABCDEFABCDEF	Ingegneria	Middle	Sviluppo Prodotto	Progettazione di nuovi prodotti
Barbara	Marrone	BCDEFGHIJKLMNOPQ	Comunicazione	Middle	Comunicazione	Gestione dei rapporti con i media
Fabio	Nere	CDEFGHIJKLMNOPQR	Supporto tecnico	Junior	Supporto	Gestione dei problemi tecnici
Emanuele	Grigie	DEFGHIJKLMNOPQRS	Vendite	Junior	Vendite	Gestione del portafoglio clienti
Elisa	Bianche	EFGHIJKLMNOPQRST	Gestione dei processi	Junior	Gestione dei processi	Ottimizzazione dei processi aziendali
Federica	Dorate	FGHIJKLMNOPQRSTU	Risorse umane	Junior	Risorse umane	Gestione delle selezioni
Giorgia	Argentate	GHIJKLMNOPQRSTUV	Amministrazione	Dirigente	Amministrazione	Gestione della contabilità
Angela	Bronzate	HIJKLMNOPQRSTUVW	Acquisti	Dirigente	Acquisti	Gestione degli acquisti aziendali
\.


--
-- Data for Name: finanziamento; Type: TABLE DATA; Schema: myschema; Owner: postgres
--

COPY myschema.finanziamento (nome, via, cup) FROM stdin;
Walmart	Ave Hostos	CUP_1
Walmart	Ave Hostos	CUP_2
Spotify	Filippo Sassetti	CUP_1
Spotify	Filippo Sassetti	CUP_2
\.


--
-- Data for Name: gestione; Type: TABLE DATA; Schema: myschema; Owner: postgres
--

COPY myschema.gestione (cf, topic, edificio, stanza) FROM stdin;
F890123456789012	AI	Palazzo delle Scienze	A1
F901234567890123	Robotica	Palazzo delle Scienze	A2
F456789012345678	Fisica	Palazzo delle Scienze	B1
F234567890123456	Chimica	Palazzo delle Tecnologie	C1
F456789012345678	Bioingegneria	Palazzo delle Tecnologie	C2
F901234567890123	Ingegneria Elettronica	Palazzo dell'Innovazione	D1
F890123456789012	Ingegneria Informatica	Palazzo dell'Innovazione	D2
\.


--
-- Data for Name: laboratorio; Type: TABLE DATA; Schema: myschema; Owner: postgres
--

COPY myschema.laboratorio (topic, edificio, stanza) FROM stdin;
AI	Palazzo delle Scienze	A1
Robotica	Palazzo delle Scienze	A2
Fisica	Palazzo delle Scienze	B1
Chimica	Palazzo delle Tecnologie	C1
Bioingegneria	Palazzo delle Tecnologie	C2
Ingegneria Elettronica	Palazzo dell'Innovazione	D1
Ingegneria Informatica	Palazzo dell'Innovazione	D2
Informatica	Ingegneria	A103
Fisica	Scienze	B205
Chimica	Scienze	C311
Biologia	Scienze	D417
Matematica	Ingegneria	E512
Robotica	Ingegneria	F608
Meccanica	Ingegneria	G714
\.


--
-- Data for Name: possessione; Type: TABLE DATA; Schema: myschema; Owner: postgres
--

COPY myschema.possessione (idcarriera, cf) FROM stdin;
1	F123456789012345
2	F234567890123456
3	F345678901234567
4	F456789012345678
5	F567890123456789
6	F678901234567890
7	F789012345678901
8	F890123456789012
9	F901234567890123
10	F012345678901234
11	F123456789012346
12	F234567890123457
13	F345678901234568
14	F456789012345679
15	F567890123456780
16	F678901234567892
17	F789012345678906
18	ABCD1234EFGH5678
19	LMNOPQRSTUVWXYZ1
20	1234567890ABCDEF
21	ABCDEFGHIJKLMNOP
22	QRSTUVWXYZABCDEF
23	GHIJKLMNOPQRSTU1
24	WXYZABCDEFABCDEF
25	BCDEFGHIJKLMNOPQ
26	CDEFGHIJKLMNOPQR
27	DEFGHIJKLMNOPQRS
28	EFGHIJKLMNOPQRST
29	FGHIJKLMNOPQRSTU
30	GHIJKLMNOPQRSTUV
31	HIJKLMNOPQRSTUVW
\.


--
-- Data for Name: progetto; Type: TABLE DATA; Schema: myschema; Owner: postgres
--

COPY myschema.progetto (cup, nome, budget) FROM stdin;
CUP_1	Progetto A	100000
CUP_2	Progetto B	150000
\.


--
-- Data for Name: referenza; Type: TABLE DATA; Schema: myschema; Owner: postgres
--

COPY myschema.referenza (cf, cup) FROM stdin;
F890123456789012	CUP_1
F901234567890123	CUP_2
\.


--
-- Data for Name: responsabilita; Type: TABLE DATA; Schema: myschema; Owner: postgres
--

COPY myschema.responsabilita (cf, cup) FROM stdin;
F678901234567890	CUP_1
F789012345678901	CUP_2
\.


--
-- Data for Name: utilizzo; Type: TABLE DATA; Schema: myschema; Owner: postgres
--

COPY myschema.utilizzo (cup, topic, edificio, stanza) FROM stdin;
CUP_1	AI	Palazzo delle Scienze	A1
CUP_1	Chimica	Palazzo delle Tecnologie	C1
CUP_1	Ingegneria Elettronica	Palazzo dell'Innovazione	D1
CUP_2	Robotica	Palazzo delle Scienze	A2
CUP_2	Bioingegneria	Palazzo delle Tecnologie	C2
CUP_2	Fisica	Palazzo delle Scienze	B1
\.


--
-- Name: carriera_idcarriera_seq; Type: SEQUENCE SET; Schema: myschema; Owner: postgres
--

SELECT pg_catalog.setval('myschema.carriera_idcarriera_seq', 31, true);


--
-- Name: contratto_idcontratto_seq; Type: SEQUENCE SET; Schema: myschema; Owner: postgres
--

SELECT pg_catalog.setval('myschema.contratto_idcontratto_seq', 31, true);


--
-- Name: azienda azienda_pk; Type: CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.azienda
    ADD CONSTRAINT azienda_pk PRIMARY KEY (nome, via);


--
-- Name: carriera carriera_pk; Type: CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.carriera
    ADD CONSTRAINT carriera_pk PRIMARY KEY (idcarriera);


--
-- Name: contratto contratto_pk; Type: CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.contratto
    ADD CONSTRAINT contratto_pk PRIMARY KEY (idcontratto);


--
-- Name: dipendente dipendente_pk; Type: CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.dipendente
    ADD CONSTRAINT dipendente_pk PRIMARY KEY (cf);


--
-- Name: utilizzo lab_unique; Type: CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.utilizzo
    ADD CONSTRAINT lab_unique UNIQUE (topic, edificio, stanza);


--
-- Name: gestione lab_unique1; Type: CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.gestione
    ADD CONSTRAINT lab_unique1 UNIQUE (topic, edificio, stanza);


--
-- Name: laboratorio laboratorio_pk; Type: CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.laboratorio
    ADD CONSTRAINT laboratorio_pk PRIMARY KEY (topic, edificio, stanza);


--
-- Name: progetto nome_unico; Type: CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.progetto
    ADD CONSTRAINT nome_unico UNIQUE (nome);


--
-- Name: possessione possessione_idcarriera_key; Type: CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.possessione
    ADD CONSTRAINT possessione_idcarriera_key UNIQUE (idcarriera);


--
-- Name: progetto progetto_pk; Type: CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.progetto
    ADD CONSTRAINT progetto_pk PRIMARY KEY (cup);


--
-- Name: referenza referenza_cup_key; Type: CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.referenza
    ADD CONSTRAINT referenza_cup_key UNIQUE (cup);


--
-- Name: responsabilita responsabilita_cup_key; Type: CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.responsabilita
    ADD CONSTRAINT responsabilita_cup_key UNIQUE (cup);


--
-- Name: responsabilita tigger_responsabilita_progetti; Type: TRIGGER; Schema: myschema; Owner: postgres
--

CREATE TRIGGER tigger_responsabilita_progetti BEFORE INSERT ON myschema.responsabilita FOR EACH ROW EXECUTE FUNCTION myschema.chiamata_trigger_reponsabilita_progetti();


--
-- Name: possessione trigger_consistenza_prima_assunzione; Type: TRIGGER; Schema: myschema; Owner: postgres
--

CREATE TRIGGER trigger_consistenza_prima_assunzione BEFORE INSERT ON myschema.possessione FOR EACH ROW EXECUTE FUNCTION myschema.consistenza_prima_assunzione();


--
-- Name: assunzione trigger_generate_contract; Type: TRIGGER; Schema: myschema; Owner: postgres
--

CREATE TRIGGER trigger_generate_contract AFTER INSERT ON myschema.assunzione FOR EACH ROW WHEN ((new.cf IS NOT NULL)) EXECUTE FUNCTION myschema.generate_contract();


--
-- Name: gestione trigger_gestione_laboratorio; Type: TRIGGER; Schema: myschema; Owner: postgres
--

CREATE TRIGGER trigger_gestione_laboratorio BEFORE INSERT ON myschema.gestione FOR EACH ROW EXECUTE FUNCTION myschema.chiamata_trigger_gestione_laboratorio();


--
-- Name: contratto trigger_indeterminato_senza_scadenza; Type: TRIGGER; Schema: myschema; Owner: postgres
--

CREATE TRIGGER trigger_indeterminato_senza_scadenza BEFORE INSERT ON myschema.contratto FOR EACH ROW WHEN ((new.tipo IS NOT NULL)) EXECUTE FUNCTION myschema.chiamata_trigger_indeterminato_senza_scadenza();


--
-- Name: referenza trigger_referenza_progetti; Type: TRIGGER; Schema: myschema; Owner: postgres
--

CREATE TRIGGER trigger_referenza_progetti BEFORE INSERT ON myschema.referenza FOR EACH ROW EXECUTE FUNCTION myschema.chiamata_trigger_referenza_progetti();


--
-- Name: utilizzo trigger_utilizzo_laboratori; Type: TRIGGER; Schema: myschema; Owner: postgres
--

CREATE TRIGGER trigger_utilizzo_laboratori BEFORE INSERT ON myschema.utilizzo FOR EACH ROW EXECUTE FUNCTION myschema.chiamata_trigger_utilizzo_laboratori();


--
-- Name: afferenza afferenza_fk1; Type: FK CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.afferenza
    ADD CONSTRAINT afferenza_fk1 FOREIGN KEY (cf) REFERENCES myschema.dipendente(cf) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: afferenza afferenza_fk2; Type: FK CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.afferenza
    ADD CONSTRAINT afferenza_fk2 FOREIGN KEY (topic, edificio, stanza) REFERENCES myschema.laboratorio(topic, edificio, stanza) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: assunzione assunzione_fk1; Type: FK CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.assunzione
    ADD CONSTRAINT assunzione_fk1 FOREIGN KEY (nome, via) REFERENCES myschema.azienda(nome, via) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: assunzione assunzione_fk2; Type: FK CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.assunzione
    ADD CONSTRAINT assunzione_fk2 FOREIGN KEY (cf) REFERENCES myschema.dipendente(cf) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: contratto contratto_fk; Type: FK CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.contratto
    ADD CONSTRAINT contratto_fk FOREIGN KEY (cf) REFERENCES myschema.dipendente(cf) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: finanziamento finanziamento_fk1; Type: FK CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.finanziamento
    ADD CONSTRAINT finanziamento_fk1 FOREIGN KEY (nome, via) REFERENCES myschema.azienda(nome, via) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: finanziamento finanziamento_fk2; Type: FK CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.finanziamento
    ADD CONSTRAINT finanziamento_fk2 FOREIGN KEY (cup) REFERENCES myschema.progetto(cup) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: gestione gestione_fk1; Type: FK CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.gestione
    ADD CONSTRAINT gestione_fk1 FOREIGN KEY (cf) REFERENCES myschema.dipendente(cf) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: gestione gestione_fk2; Type: FK CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.gestione
    ADD CONSTRAINT gestione_fk2 FOREIGN KEY (topic, edificio, stanza) REFERENCES myschema.laboratorio(topic, edificio, stanza) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: possessione possessione_fk1; Type: FK CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.possessione
    ADD CONSTRAINT possessione_fk1 FOREIGN KEY (idcarriera) REFERENCES myschema.carriera(idcarriera) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: possessione possessione_fk2; Type: FK CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.possessione
    ADD CONSTRAINT possessione_fk2 FOREIGN KEY (cf) REFERENCES myschema.dipendente(cf) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: referenza referenza_fk1; Type: FK CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.referenza
    ADD CONSTRAINT referenza_fk1 FOREIGN KEY (cf) REFERENCES myschema.dipendente(cf) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: referenza referenza_fk2; Type: FK CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.referenza
    ADD CONSTRAINT referenza_fk2 FOREIGN KEY (cup) REFERENCES myschema.progetto(cup) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: responsabilita responsabilita_fk1; Type: FK CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.responsabilita
    ADD CONSTRAINT responsabilita_fk1 FOREIGN KEY (cf) REFERENCES myschema.dipendente(cf) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: responsabilita responsabilità_fk2; Type: FK CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.responsabilita
    ADD CONSTRAINT "responsabilità_fk2" FOREIGN KEY (cup) REFERENCES myschema.progetto(cup) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: utilizzo utilizzo_fk1; Type: FK CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.utilizzo
    ADD CONSTRAINT utilizzo_fk1 FOREIGN KEY (cup) REFERENCES myschema.progetto(cup) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: utilizzo utilizzo_fk2; Type: FK CONSTRAINT; Schema: myschema; Owner: postgres
--

ALTER TABLE ONLY myschema.utilizzo
    ADD CONSTRAINT utilizzo_fk2 FOREIGN KEY (topic, edificio, stanza) REFERENCES myschema.laboratorio(topic, edificio, stanza) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

