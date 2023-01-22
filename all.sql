DROP SCHEMA IF EXISTS MYSCHEMA CASCADE;
CREATE SCHEMA MYSCHEMA;
SET SEARCH_PATH TO MYSCHEMA;


--Domino tipo contratto
CREATE DOMAIN Tipo_C AS VARCHAR(100)
CHECK(VALUE='Indeterminato' OR VALUE='Determinato');

--Dominio Ruoli
CREATE DOMAIN Categoria AS VARCHAR(100)
CHECK(VALUE='Junior' OR VALUE='Middle' OR VALUE='Senior' OR VALUE='Dirigente');

--Dominio Aumento Stipendio
CREATE DOMAIN Percentuale AS FLOAT
CHECK(VALUE>=0 AND VALUE<=1);

CREATE TABLE AZIENDA(
    Nome VARCHAR(100),
    Titolare VARCHAR(100),
    Via VARCHAR(100),
    Civico VARCHAR(100),
    CAP VARCHAR(100),
    Fatturato float,
    CONSTRAINT azienda_pk primary key(Nome,Via),
    CONSTRAINT validita_nome_azienda CHECK (Nome ~ '[a-z]' OR Nome ~ '[A-Z]' OR Nome ~ '[0-9]'), 
    CONSTRAINT validita_titolare CHECK (Titolare ~ '[a-z]' OR Titolare ~ '[A-Z]')
);

CREATE TABLE DIPENDENTE(
    Nome VARCHAR(100),
    Cognome VARCHAR(100),
    CF CHAR(16),
    Specializzazione VARCHAR(150),
    Ruolo Categoria,
    Ufficio VARCHAR(100),
    Mansione VARCHAR(200),
    CONSTRAINT dipendente_pk primary key(CF),
    CONSTRAINT validita_nome CHECK (Nome ~ '[A-Z]' OR Nome ~ '[a-z]'),
    CONSTRAINT validita_cognome CHECK (Cognome ~ '[A-Z]' OR Cognome ~ '[a-z]'),
    CONSTRAINT validita_cf CHECK ((CF ~ '[A-Z]' OR CF ~ '[0-9]' ) AND char_length(CF)=16)
);

CREATE TABLE CONTRATTO(
    IDContratto serial,
    Tipo Tipo_C,
    DataFirma TIMESTAMP,
    ScadenzaContratto TIMESTAMP,
    Stipendio float,
    CF CHAR(16),
    CONSTRAINT contratto_pk primary key(IDContratto),
    CONSTRAINT validita_data_contratto          CHECK(ScadenzaContratto>DataFirma), --Validità data contratto
    CONSTRAINT contratto_fk foreign key(CF) references Dipendente(CF) ON UPDATE CASCADE ON DELETE CASCADE
);


CREATE TABLE LABORATORIO(
    Topic VARCHAR(100),
    Edificio VARCHAR(100),
    Stanza VARCHAR(100),
    CONSTRAINT laboratorio_pk primary key(Topic,Edificio,Stanza)
);

CREATE TABLE PROGETTO(
    CUP VARCHAR(100), 
    Nome VARCHAR(100),
    Budget float,
    CONSTRAINT progetto_pk primary key(CUP),
    CONSTRAINT nome_unico unique(Nome) --Nome Progetto
);

CREATE TABLE UTILIZZO(
    CUP VARCHAR(100),
    Topic VARCHAR(100),
    Edificio VARCHAR(100),
    Stanza VARCHAR(100),
    CONSTRAINT lab_unique UNIQUE(Topic,Edificio,Stanza),
    CONSTRAINT utilizzo_fk1 foreign key(CUP) references Progetto(CUP) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT utilizzo_fk2 foreign key(Topic,Edificio,Stanza) references Laboratorio(Topic,Edificio,Stanza) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE CARRIERA(
    IDCarriera serial,
    PrimaAssunzione TIMESTAMP,
    DataPromozione TIMESTAMP,
    RuoloPrecedente Categoria,
    AumentoStipendio Percentuale,
    StipendioCorrente float,
    StipendioPrecedente float,
    CONSTRAINT carriera_pk primary key(IDCarriera),
    CONSTRAINT validita_data_carriera CHECK(DataPromozione>=PrimaAssunzione)
);

CREATE TABLE POSSESSIONE(
    IDCarriera int UNIQUE, 
    CF CHAR(16),
    CONSTRAINT possessione_fk1 foreign key(IDCarriera) references Carriera(IDCarriera) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT possessione_fk2 foreign key(CF) references Dipendente(CF) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE ASSUNZIONE(
    Nome VARCHAR(100),
    Via VARCHAR(100),
    CF CHAR(16),
    CONSTRAINT assunzione_fk1 foreign key(Nome,Via) references Azienda(Nome,Via) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT assunzione_fk2 foreign key(CF) references Dipendente(CF) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE FINANZIAMENTO(
    Nome VARCHAR(100),
    Via VARCHAR(100),
    CUP VARCHAR(100),
    CONSTRAINT finanziamento_fk1 foreign key(Nome,Via) references Azienda(Nome,Via) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT finanziamento_fk2 foreign key(CUP) references Progetto(CUP) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE AFFERENZA(
    CF CHAR(16),
    Topic VARCHAR(100),
    Edificio VARCHAR(100),
    Stanza VARCHAR(100),
    CONSTRAINT afferenza_fk1 foreign key(CF) references Dipendente(CF) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT afferenza_fk2 foreign key(Topic,Edificio,Stanza) references Laboratorio(Topic,Edificio,Stanza) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE RESPONSABILITA(
    CF CHAR(16),
    CUP VARCHAR(100) UNIQUE,
    CONSTRAINT responsabilita_fk1 foreign key(CF) references Dipendente(CF) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT responsabilità_fk2 foreign key(CUP) references Progetto(CUP) ON UPDATE CASCADE ON DELETE CASCADE
);


CREATE TABLE GESTIONE(
    CF CHAR(16),
    Topic VARCHAR(100),
    Edificio VARCHAR(100),
    Stanza VARCHAR(100),
    CONSTRAINT lab_unique1 UNIQUE(Topic,Edificio,Stanza),
    CONSTRAINT gestione_fk1 foreign key(CF) references Dipendente(CF) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT gestione_fk2 foreign key(Topic,Edificio,Stanza) references Laboratorio(Topic,Edificio,Stanza) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE REFERENZA(
    CF CHAR(16),
    CUP VARCHAR(100) UNIQUE,
    CONSTRAINT referenza_fk1 foreign key(CF) references Dipendente(CF) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT referenza_fk2 foreign key(CUP) references Progetto(CUP) ON UPDATE CASCADE ON DELETE CASCADE
);

--****************************************************TRIGGER, FUNCTIONS AND VIEWS********************************************************************
--Indeterminato senza scadenza: questa trigger function verifica che all'inserimento di un Contratto, se il tipo è Indeterminato allora la scadenza deve essere null, altrimenti se il tipo è Determinato, la scadenza non deve essere null.
CREATE OR REPLACE FUNCTION Chiamata_Trigger_Indeterminato_Senza_Scadenza() RETURNS TRIGGER AS $$
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
$$
language plpgsql;

CREATE OR REPLACE TRIGGER Trigger_Indeterminato_Senza_Scadenza BEFORE INSERT ON Contratto
FOR EACH ROW
WHEN(new.Tipo IS NOT NULL)
EXECUTE PROCEDURE Chiamata_Trigger_Indeterminato_Senza_Scadenza();
-------------------------------------------------------------------------------------------------------------------------
--Questa funzione serve per modificare un contratto da tempo determinato a tempo indeterminato
CREATE OR REPLACE FUNCTION ToIndeterminate(CODICEF Dipendente.CF%TYPE) RETURNS BOOLEAN AS $$
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
$$
language plpgsql;
-------------------------------------------------------------------------------------------------------------------------
--ScadenzaContratto: queste funzioni servono per rinnovare i contratti a tempo Determinato qual'ora fossero scaduti
CREATE OR REPLACE FUNCTION IsObsolete(CODICEF IN Dipendente.CF%TYPE) RETURNS BOOLEAN AS $$
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
$$
language plpgsql;
----------------------------------------------------------------------------
--Rinnovo del contratto
CREATE OR REPLACE FUNCTION Renewal_Contract(CODICEF IN Dipendente.CF%TYPE) RETURNS BOOLEAN AS $$
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
$$
language plpgsql;
---------------------------------------------------------------------------------------------------------------------------------
--Questa funzione verifica se tutti i dipendenti di una certa azienda sono idonei al rinnovo contratto
CREATE OR REPLACE PROCEDURE Check_For_Global_Renewal(nome IN Azienda.NOME%TYPE, via IN Azienda.VIA%TYPE) AS $$
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
$$
language plpgsql;
-------------------------------------------------------------------------------------------------------------------------
--Generazione automatica del contratto al momento dell'assunzione dei dipendenti
CREATE OR REPLACE FUNCTION Generate_Contract() RETURNS TRIGGER AS $$
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
$$
language plpgsql;

CREATE OR REPLACE TRIGGER Trigger_Generate_Contract AFTER INSERT ON ASSUNZIONE
FOR EACH ROW
WHEN(New.CF IS NOT NULL)
EXECUTE PROCEDURE Generate_Contract();


-------------------------------------------------------------------------------------------------------------------------
--Utilizzo Laboratori: questa trigger function serve nel momento in cui 
--ad un progetto vengono assegnati più di 3 laboratori, questa situazione genera un problema
CREATE OR REPLACE FUNCTION Chiamata_Trigger_Utilizzo_Laboratori() RETURNS TRIGGER AS $$
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
$$
language plpgsql;

CREATE OR REPLACE TRIGGER Trigger_Utilizzo_Laboratori BEFORE INSERT ON UTILIZZO 
FOR EACH ROW
EXECUTE PROCEDURE Chiamata_Trigger_Utilizzo_Laboratori();

----------------------------------------------------------------------------------------
--Conteggio anni di lavoro: conto quanti anni ha lavorato il dipendente nell'azienda
CREATE OR REPLACE FUNCTION Anni_Lavoro(CODICEF IN Dipendente.CF%TYPE) RETURNS INTEGER AS $$
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
$$
language plpgsql;
---------------------------------------------------------------------------------------------------------
--PassaggioDirigente: questa funzione serve per effettuare il passaggio dal ruolo attuale a Dirigente
CREATE OR REPLACE FUNCTION passaggio_Dirigente(CODICEF IN Dipendente.CF%TYPE) RETURNS BOOLEAN AS $$
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
$$
language plpgsql;

---------------------------------------------------------------------------------------------------------
--Anzianità: questa funzione verifica in quale range di anni il dipendente
-- sta lavorando e in base a quel range effettua il passaggio adeguato
CREATE OR REPLACE FUNCTION Anzianita(CODICEF IN Dipendente.CF%TYPE) RETURNS BOOLEAN AS $$
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
$$
language plpgsql;
---------------------------------------------------------------------------------------------------------
--Passaggio a Middle
CREATE OR REPLACE FUNCTION passaggio_middle(CODICEF IN Dipendente.CF%TYPE) RETURNS BOOLEAN AS $$
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
$$
language plpgsql;
-----------------------------------
--Passaggio a Senior
CREATE OR REPLACE FUNCTION passaggio_senior(CODICEF IN Dipendente.CF%TYPE) RETURNS BOOLEAN AS $$
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
$$
language plpgsql;
---------------------------------------------------------------------------------------------------------
--Questa funzione serve per verificare se un dipendente è idoneo al passaggio di ruolo
CREATE OR REPLACE PROCEDURE Check_For_Promotion(CODICEF IN Dipendente.CF%TYPE) AS $$
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
$$
language plpgsql;
---------------------------------------
--Questa funzione verifica se tutti i dipendenti di una certa azienda sono idonei al passaggio di ruolo
CREATE OR REPLACE PROCEDURE Check_For_Global_Promotion(nome IN Azienda.NOME%TYPE, via IN Azienda.VIA%TYPE) AS $$
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
$$
language plpgsql;

----------------------------------------------------------------------------------------------------------
--Aumento dello stipendio: questa funzione inserisce una nuova carriera al
--dipendente e effettua opportuni calcoli in base al valore di aumento stipendio
CREATE OR REPLACE FUNCTION Aumento_Stipendio(CODICEF IN Dipendente.CF%TYPE, valore IN float) RETURNS BOOLEAN AS $$
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
$$
language plpgsql;
-------------------------
--Questa procedura permette di avere un feedback visivo riguardo alla promozione del salario di un dipendente
CREATE OR REPLACE PROCEDURE Chiama_Aumento_Stipendio(CODICEF IN Dipendente.CF%TYPE, valore IN float) AS $$
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
$$
language plpgsql;

--------------------------------------------------------------------------------------------------------------------
--Consistenza Prima Assunzione: questa trigger function verifica che
-- la data di firma di un contratto coincida con la data di prima assunzione di una carriera
CREATE OR REPLACE FUNCTION Consistenza_Prima_Assunzione() RETURNS TRIGGER AS $$
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
$$
language plpgsql;

CREATE OR REPLACE TRIGGER Trigger_Consistenza_Prima_Assunzione BEFORE INSERT ON POSSESSIONE
FOR EACH ROW
EXECUTE PROCEDURE Consistenza_Prima_Assunzione();

-------------------------------------------------------------------------------------------------
--Responsabilità progetti: questa trigger function verifica che
-- all'inserimento di una tupla responsabilità il dipendente sia Dirigente
CREATE OR REPLACE FUNCTION Chiamata_Trigger_Reponsabilita_Progetti() RETURNS TRIGGER AS $$
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
$$
language plpgsql;

CREATE OR REPLACE TRIGGER Tigger_Responsabilita_Progetti BEFORE INSERT ON RESPONSABILITA
FOR EACH ROW
EXECUTE PROCEDURE Chiamata_Trigger_Reponsabilita_Progetti();
----------------------------------------------------------------------------------------------------------
--Gestione laboratorio: questa trigger function verifica che all'inserimento di una tupla gestione il dipendente sia Senior
CREATE OR REPLACE FUNCTION Chiamata_Trigger_Gestione_Laboratorio() RETURNS TRIGGER AS $$
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
$$
language plpgsql;


CREATE OR REPLACE TRIGGER Trigger_Gestione_Laboratorio BEFORE INSERT ON GESTIONE
FOR EACH ROW
EXECUTE PROCEDURE Chiamata_Trigger_Gestione_Laboratorio();
-------------------------------------------------------------------------------------------------
--Referenza progetti: questa trigger function verifica che all'inserimento di una tupla referenza il dipendente sia Senior
CREATE OR REPLACE FUNCTION Chiamata_Trigger_Referenza_Progetti() RETURNS TRIGGER AS $$
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
$$
language plpgsql;


CREATE OR REPLACE TRIGGER Trigger_Referenza_Progetti BEFORE INSERT ON REFERENZA
FOR EACH ROW
EXECUTE PROCEDURE Chiamata_Trigger_Referenza_Progetti();

-----------------------------------------------------------------------------------------------------
--Numero di impiegati aziendali per ciascuna azienda
CREATE VIEW Numero_Impiegati_Aziendali AS
SELECT Nome,COUNT(CF) AS Num_Imp
FROM ASSUNZIONE
GROUP BY Nome;

--Numero di afferenti di un laboratorio per ciascun topic
CREATE VIEW Numero_Afferenti_Lab AS
SELECT Topic, Edificio, Stanza, COUNT(CF) AS Num_Aff
FROM AFFERENZA
GROUP BY Topic, Edificio, Stanza;

--VIEW PER CARRIERA CON CONTRATTO
CREATE VIEW CarrieraConContratto AS
SELECT P1.CF,C1.DATAPROMOZIONE AS DataPromozioneCarriera,C1.STIPENDIOCORRENTE AS UltimoStipendio, C2.DATAFIRMA AS DataFirmaContratto,C2.TIPO AS TipoContratto,C2.SCADENZACONTRATTO AS ScadenzaContratto
FROM (CARRIERA AS C1 JOIN POSSESSIONE AS P1 ON C1.IDCARRIERA=P1.IDCARRIERA)
JOIN CONTRATTO AS C2 ON C2.CF=P1.CF
GROUP BY P1.CF,C1.DATAPROMOZIONE, C1.STIPENDIOCORRENTE, C2.DATAFIRMA,C2.TIPO,C2.SCADENZACONTRATTO
ORDER BY C1.DATAPROMOZIONE DESC;

------------------------------------------------------------------------------------------------------------------------------
--WALMART
INSERT INTO AZIENDA (Nome, Titolare, Via, Civico, Cap, Fatturato)
VALUES
    ('Walmart','Carl Douglas McMillon', 'Ave Hostos', '975', '00680', 1200000);

INSERT INTO DIPENDENTE (Nome, Cognome, CF, Specializzazione, Ruolo, Ufficio, Mansione)
VALUES 
    ('Mario','Rossi','F123456789012345','Informatica','Junior','IT','Settore IT'),
    ('Luca','Bianchi','F234567890123456','Marketing','Senior','Marketing','Settore Marketing'),
    ('Chiara','Verde','F345678901234567','Contabilità','Junior','Amministrazione','Settore Amministrativo'),
    ('Giovanni','Nero','F456789012345678','Vendite','Senior','Vendite','Settore vendite'),
    ('Simone','Grigio','F567890123456789','Risorse Umane','Junior','Risorse Umane','Settore Risorse Umane'),
    ('Paola','Marrone','F678901234567890','Produzione','Dirigente','Produzione','Settore Produzione'),
    ('Giuseppe','Giallo','F789012345678901','Design','Dirigente','Design','Settore design'),
    ('Antonia','Arancione','F890123456789012','Sviluppo','Senior','Sviluppo','Settore Sviluppo'),
    ('Edoardo','Rosso','F901234567890123','Qualità','Senior','Qualità','Settore Qualità'),
    ('Francesca','Viola','F012345678901234','Progettazione','Junior','Progettazione','Settore Progettazione'),
    ('Stefano','Blu','F123456789012346','Rapporti Pubblici','Junior','Rapporti Pubblici','Settore rapporti pubblici'),
    ('Elisa','Verde','F234567890123457','Sicurezza','Middle','Sicurezza','Settore Sicurezza'),
    ('Alessio','Giallo','F345678901234568','Acquisti','Middle','Acquisti','Settore Acquisti'),
    ('Eleonora','Bianco','F456789012345679','Stampa','Junior','Stampa','Settore Stampa'),
    ('Giorgia','Nero','F567890123456780','Innovazione','Middle','Innovazione','Settore Innovazione'),
    ('Ginevra','Grigio','F678901234567892','Sviluppo Prodotto','Junior','Sviluppo Prodotto','Settore Sviluppo Prodotto'),
    ('Lorenzo','Marrone','F789012345678906','Comunicazione','Junior','Comunicazione','Settore Comunicazione');

INSERT INTO ASSUNZIONE (Nome, Via, Cf)
VALUES
    ('Walmart', 'Ave Hostos', 'F123456789012345'),
    ('Walmart', 'Ave Hostos', 'F234567890123456'),
    ('Walmart', 'Ave Hostos', 'F345678901234567'),
    ('Walmart', 'Ave Hostos', 'F456789012345678'),
    ('Walmart', 'Ave Hostos', 'F567890123456789'),
    ('Walmart', 'Ave Hostos', 'F678901234567890'),
    ('Walmart', 'Ave Hostos', 'F789012345678901'),
    ('Walmart', 'Ave Hostos', 'F890123456789012'),
    ('Walmart', 'Ave Hostos', 'F901234567890123'),
    ('Walmart', 'Ave Hostos', 'F012345678901234'),
    ('Walmart', 'Ave Hostos', 'F123456789012346'),
    ('Walmart', 'Ave Hostos', 'F234567890123457'),
    ('Walmart', 'Ave Hostos', 'F345678901234568'),
    ('Walmart', 'Ave Hostos', 'F456789012345679'),
    ('Walmart', 'Ave Hostos', 'F567890123456780'),
    ('Walmart', 'Ave Hostos', 'F678901234567892'),
    ('Walmart', 'Ave Hostos', 'F789012345678906');

INSERT INTO LABORATORIO (Topic, Edificio, Stanza)
VALUES 
    ('AI','Palazzo delle Scienze','A1'),
    ('Robotica','Palazzo delle Scienze','A2'),
    ('Fisica','Palazzo delle Scienze','B1'),
    ('Chimica','Palazzo delle Tecnologie','C1'),
    ('Bioingegneria','Palazzo delle Tecnologie','C2'),
    ('Ingegneria Elettronica','Palazzo dell''Innovazione','D1'),
    ('Ingegneria Informatica','Palazzo dell''Innovazione','D2'); --TRIGGER

INSERT INTO PROGETTO (CUP, Nome, Budget)
VALUES
    ('CUP_1', 'Progetto A', 100000.00),
    ('CUP_2', 'Progetto B', 150000.00);

INSERT INTO UTILIZZO (CUP, Topic, Edificio, Stanza)
VALUES
    ('CUP_1', 'AI','Palazzo delle Scienze','A1'),
    ('CUP_1', 'Chimica','Palazzo delle Tecnologie','C1'),
    ('CUP_1', 'Ingegneria Elettronica','Palazzo dell''Innovazione','D1'),
    ('CUP_2', 'Robotica','Palazzo delle Scienze','A2'),
    ('CUP_2', 'Bioingegneria','Palazzo delle Tecnologie','C2'),
    ('CUP_2', 'Fisica','Palazzo delle Scienze','B1');

INSERT INTO FINANZIAMENTO (Nome, Via, CUP)
VALUES
    ('Walmart', 'Ave Hostos', 'CUP_1'),
    ('Walmart', 'Ave Hostos', 'CUP_2');

INSERT INTO AFFERENZA (CF, Topic, Edificio, Stanza)
VALUES
    ('F123456789012345', 'AI','Palazzo delle Scienze','A1'),
    ('F234567890123456', 'Robotica','Palazzo delle Scienze','A2'),
    ('F345678901234567', 'Chimica','Palazzo delle Tecnologie','C1'),
    ('F456789012345678', 'Bioingegneria','Palazzo delle Tecnologie','C2'),
    ('F567890123456789', 'Ingegneria Elettronica','Palazzo dell''Innovazione','D1'),
    ('F678901234567890', 'Bioingegneria','Palazzo delle Tecnologie','C2'),
    ('F789012345678901', 'AI','Palazzo delle Scienze','A1'),
    ('F890123456789012', 'Fisica','Palazzo delle Scienze','B1'),
    ('F901234567890123', 'Robotica','Palazzo delle Scienze','A2'),
    ('F012345678901234', 'Fisica','Palazzo delle Scienze','B1'),
    ('F123456789012346', 'Ingegneria Elettronica','Palazzo dell''Innovazione','D1'),
    ('F234567890123457', 'AI','Palazzo delle Scienze','A1');

INSERT INTO RESPONSABILITA (CF, CUP)
VALUES
    ('F678901234567890', 'CUP_1'),
    ('F789012345678901', 'CUP_2');

INSERT INTO GESTIONE (CF, Topic, Edificio, Stanza)
VALUES
    ('F890123456789012', 'AI','Palazzo delle Scienze','A1'),
    ('F901234567890123', 'Robotica','Palazzo delle Scienze','A2'),
    ('F456789012345678', 'Fisica','Palazzo delle Scienze','B1'),
    ('F234567890123456', 'Chimica','Palazzo delle Tecnologie','C1'),
    ('F456789012345678', 'Bioingegneria','Palazzo delle Tecnologie','C2'),
    ('F901234567890123', 'Ingegneria Elettronica','Palazzo dell''Innovazione','D1'),
    ('F890123456789012', 'Ingegneria Informatica','Palazzo dell''Innovazione','D2');

INSERT INTO REFERENZA (CF, CUP)
VALUES
    ('F890123456789012', 'CUP_1'),
    ('F901234567890123', 'CUP_2');
--------------------------------------------------------------------------------
--SPOTIFY
INSERT INTO AZIENDA (Nome, Titolare, Via, Civico, Cap, Fatturato)
VALUES
    ('Spotify','Daniel Ek', 'Filippo Sassetti', '32', '20124', 2000000);

INSERT INTO DIPENDENTE (Nome, Cognome, CF, Specializzazione, Ruolo, Ufficio, Mansione)
VALUES 
    ('Mario', 'Rossi', 'ABCD1234EFGH5678', 'Informatica', 'Senior', 'Marketing', 'Responsabile del team'),
    ('Luca', 'Bianchi', 'LMNOPQRSTUVWXYZ1',  'Gestione delle risorse umane', 'Senior', 'Amministrazione', 'Gestione del personale'),
    ('Paolo', 'Verdi', '1234567890ABCDEF', 'Finanza', 'Senior', 'Finanza', 'Gestione del budget'),
    ('Chiara', 'Gialli', 'ABCDEFGHIJKLMNOP', 'Marketing', 'Middle', 'Marketing', 'Sviluppo delle campagne pubblicitarie'),
    ('Giovanni', 'Blu', 'QRSTUVWXYZABCDEF', 'Sviluppo software', 'Middle', 'Informatica', 'Sviluppo di nuove funzionalità'),
    ('Roberta', 'Viola', 'GHIJKLMNOPQRSTU1', 'Gestione dei progetti', 'Middle', 'IT', 'Coordinamento del team di progetto'),
    ('Andrea', 'Arancioni', 'WXYZABCDEFABCDEF', 'Ingegneria', 'Middle', 'Sviluppo Prodotto', 'Progettazione di nuovi prodotti'),
    ('Barbara', 'Marrone', 'BCDEFGHIJKLMNOPQ', 'Comunicazione', 'Middle', 'Comunicazione', 'Gestione dei rapporti con i media'),
    ('Fabio', 'Nere', 'CDEFGHIJKLMNOPQR', 'Supporto tecnico', 'Junior', 'Supporto', 'Gestione dei problemi tecnici'),
    ('Emanuele', 'Grigie', 'DEFGHIJKLMNOPQRS', 'Vendite', 'Junior', 'Vendite', 'Gestione del portafoglio clienti'),
    ('Elisa', 'Bianche', 'EFGHIJKLMNOPQRST', 'Gestione dei processi', 'Junior', 'Gestione dei processi', 'Ottimizzazione dei processi aziendali'),
    ('Federica', 'Dorate', 'FGHIJKLMNOPQRSTU', 'Risorse umane', 'Junior', 'Risorse umane', 'Gestione delle selezioni'),
    ('Giorgia', 'Argentate', 'GHIJKLMNOPQRSTUV', 'Amministrazione', 'Dirigente', 'Amministrazione', 'Gestione della contabilità'),
    ('Angela', 'Bronzate', 'HIJKLMNOPQRSTUVW', 'Acquisti', 'Dirigente', 'Acquisti', 'Gestione degli acquisti aziendali');

INSERT INTO ASSUNZIONE (Nome, Via, Cf)
VALUES
    ('Spotify', 'Filippo Sassetti', 'ABCD1234EFGH5678'),
    ('Spotify', 'Filippo Sassetti', 'LMNOPQRSTUVWXYZ1'),
    ('Spotify', 'Filippo Sassetti', '1234567890ABCDEF'),
    ('Spotify', 'Filippo Sassetti', 'ABCDEFGHIJKLMNOP'),
    ('Spotify', 'Filippo Sassetti', 'QRSTUVWXYZABCDEF'),
    ('Spotify', 'Filippo Sassetti', 'GHIJKLMNOPQRSTU1'),
    ('Spotify', 'Filippo Sassetti', 'WXYZABCDEFABCDEF'),
    ('Spotify', 'Filippo Sassetti', 'BCDEFGHIJKLMNOPQ'),
    ('Spotify', 'Filippo Sassetti', 'CDEFGHIJKLMNOPQR'),
    ('Spotify', 'Filippo Sassetti', 'DEFGHIJKLMNOPQRS'),
    ('Spotify', 'Filippo Sassetti', 'EFGHIJKLMNOPQRST'),
    ('Spotify', 'Filippo Sassetti', 'FGHIJKLMNOPQRSTU'),
    ('Spotify', 'Filippo Sassetti', 'GHIJKLMNOPQRSTUV'),
    ('Spotify', 'Filippo Sassetti', 'HIJKLMNOPQRSTUVW');

INSERT INTO LABORATORIO (Topic, Edificio, Stanza)
VALUES 
    ('Informatica', 'Ingegneria', 'A103'),
    ('Fisica', 'Scienze', 'B205'),
    ('Chimica', 'Scienze', 'C311'),
    ('Biologia', 'Scienze', 'D417'),
    ('Matematica', 'Ingegneria', 'E512'),
    ('Robotica', 'Ingegneria', 'F608'),
    ('Meccanica', 'Ingegneria', 'G714');

INSERT INTO FINANZIAMENTO (Nome, Via, CUP)
VALUES
    ('Spotify', 'Filippo Sassetti', 'CUP_1'),
    ('Spotify', 'Filippo Sassetti', 'CUP_2');



