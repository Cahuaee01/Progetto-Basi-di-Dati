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





