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