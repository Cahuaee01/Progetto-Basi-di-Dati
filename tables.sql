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
