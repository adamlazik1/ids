/**
* Súbor: xlazik00_xlasmi00.sql
* Autori: Adam Lazík (xlazik00), Michal Ľaš (xlasmi00)
* Dátum: 26.03.2023
*/

---------------------------------------------
------- Definície overovacích funkcií -------
---------------------------------------------

CREATE OR REPLACE TYPE numarray IS VARRAY(10) of NUMBER;
/
-- Validácia čísla účtu podľa https://www.kutac.cz/pocitace-a-internety/jak-poznat-spravne-cislo-uctu
CREATE OR REPLACE FUNCTION VERIFY_BANK_ACCOUNT_NUMBER(acc_no_full IN VARCHAR2) RETURN NUMBER DETERMINISTIC IS
    acc_no VARCHAR2(10);
    prefix VARCHAR2(10);
    weights numarray;
    total NUMBER;
    total_prefix NUMBER;
BEGIN
    IF (REGEXP_LIKE(acc_no_full, '^(\d{2,6}-)?\d{1,10}/\d{4}$') = FALSE) THEN
        RETURN 0;
    END IF;
    weights := numarray(6, 3, 7, 9, 10, 5, 8, 4, 2, 1);
    acc_no := REGEXP_REPLACE(acc_no_full, '\d+-|/\d+', '');
    acc_no := LPAD(acc_no, 10, '0');
    IF (REGEXP_LIKE(acc_no_full, '-')) THEN
        prefix := REGEXP_REPLACE(acc_no_full, '-\d+/\d+', '');
        prefix := LPAD(prefix, 10, '0');
    ELSE
        prefix := '0000000000';
    END IF;
    total := 0;
    total_prefix := 0;
    FOR i in 1 .. 10 LOOP
        total := total + weights(i)*TO_NUMBER(SUBSTR(acc_no, i, 1));
        total_prefix := total_prefix + weights(i)*TO_NUMBER(SUBSTR(prefix, i, 1));
    END LOOP;
    IF (MOD(total, 11) + MOD(total_prefix, 11) = 0) THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
END;
/
-- Validácia IČA podľa https://cs.wikipedia.org/wiki/Identifika%C4%8Dn%C3%AD_%C4%8D%C3%ADslo_osoby
CREATE OR REPLACE FUNCTION VERIFY_ICO(ico IN VARCHAR2) RETURN NUMBER DETERMINISTIC IS
    weights numarray;
    total NUMBER;
BEGIN
    IF (REGEXP_LIKE(ico, '\d{8}') = FALSE) THEN
        RETURN 0;
    END IF;
    -- Posledné tri číslice nie sú použité ale zabraňujú nutnosti definovať nový dátový typ
    weights := numarray(8, 7, 6, 5, 4, 3, 2, 0, 0, 0);
    total := 0;
    FOR i in 1 .. 7 LOOP
        total := total + weights(i)*TO_NUMBER(SUBSTR(ico, i, 1));
    END LOOP;
    IF (MOD(11 - MOD(total, 11), 10) = TO_NUMBER(SUBSTR(ico, 8, 1))) THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
END;
/
-------------------------
-- Vytváranie sekvecií --
-------------------------

CREATE SEQUENCE Var_symbol_seq
START WITH 10000000
INCREMENT BY 1
MAXVALUE 99999999
NOCACHE
NOCYCLE;

-------------------------
-- Vytváranie tabuliek --
-------------------------


CREATE TABLE zakaznik (
    ID_zakaznik NUMBER(10) GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    Priezvisko VARCHAR2(64) NOT NULL,
    Meno VARCHAR2(64) NOT NULL,
    Titul VARCHAR2(32),
    -- Skladovanie číselných hodnôt vo VARCHAR2 kvôli vedúcim nulám
    Tel VARCHAR2(16) NOT NULL,
    Email VARCHAR2(64) NOT NULL,
    Ulica VARCHAR2(64) NOT NULL,
    Mesto VARCHAR2(64) NOT NULL,
    PSC VARCHAR2(5) NOT NULL,

    CONSTRAINT Zk_check_email CHECK (REGEXP_LIKE(Email, '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]+$')),
    -- Podporované sú najbežnejšie formáty českých tel. č.:
    -- +420 777 777 777
    -- +420777777777
    -- 777 777 777
    -- 777777777
    CONSTRAINT Zk_check_tel CHECK (REGEXP_LIKE(Tel, '(\+\d{3} ?)?(\d{3} ?){2}\d{3}')),
    CONSTRAINT Zk_check_PSC CHECK (REGEXP_LIKE(PSC, '\d{5}'))
);


CREATE TABLE objednavka (
    Cislo_objednavky NUMBER(8) GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    Ulica VARCHAR2(64) NOT NULL,
    Mesto VARCHAR2(64) NOT NULL,
    PSC VARCHAR2(5) NOT NULL,
    Zaciatok_vystavby DATE,
    Ukoncenie_vystavby DATE,
    Popis VARCHAR2(500),
    Status VARCHAR2(32),
    Posledna_uprava DATE,
    Specifikacia VARCHAR2(255), -- Cesta k súboru so špecifikáciou

    CONSTRAINT Obj_check_PSC CHECK (REGEXP_LIKE(PSC, '\d{5}')),

    ID_zakaznik NUMBER(10) NOT NULL,
    CONSTRAINT fk_objednavka_zakaznik FOREIGN KEY (ID_zakaznik)
    REFERENCES zakaznik(ID_zakaznik)
    ON DELETE SET NULL
);


-------------------------------------------
-- Generalizácia/Špecializácia
-- Vzťahy boli upravené podľa spätnej väzby hodnotenia prvej časti projektu
-- Nadtyp (zamestnanec) + podtyp (externy_zamestnanec) + podtyp (vlastny_zamestnanec)
-- Nadtyp (vlastny_zamestnanec) + podtyp (povereny_pracovnik)
-- Podtypy obsahujú primárny kľúč nadtypu
-- Zvolili sme tento spôsob kvôli prehľadnosti

CREATE TABLE zamestnanec (
    ID_zamestnanca NUMBER(8) GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    Priezvisko VARCHAR2(32) NOT NULL,
    Meno VARCHAR2(32) NOT NULL,
    Titul VARCHAR2(32),
    Specializacia VARCHAR2(64) NOT NULL,
    Tel VARCHAR2(16) NOT NULL,
    Email VARCHAR2(32) NOT NULL,
    Cislo_uctu VARCHAR2(22) NOT NULL,
    Var_symbol NUMBER(8) DEFAULT Var_symbol_seq.NEXTVAL,

    CONSTRAINT Zm_check_email CHECK (REGEXP_LIKE(Email, '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]+$')),
    CONSTRAINT Zm_check_tel CHECK (REGEXP_LIKE(Tel, '(\+\d{3} ?)?(\d{3} ?){2}\d{3}')),

    -- Užívateľské funkcie nemôžu byť volané v CHECK priamo, nutnosť vytvoriť extra stĺpec s výsledkom funkcie
    Ucet_valid NUMBER(1) GENERATED ALWAYS AS (VERIFY_BANK_ACCOUNT_NUMBER(Cislo_uctu)) VIRTUAL,
    CONSTRAINT Zm_check_cislo_uctu CHECK (Ucet_valid = 1)
);

CREATE TABLE externy_zamestnanec (
    ID_zamestnanca NUMBER(8) PRIMARY KEY,
    ICO VARCHAR2(8) NOT NULL,
    DIC VARCHAR2(12) NOT NULL,
    Nazov_firmy VARCHAR2(64) NOT NULL,

    ICO_valid NUMBER(1) GENERATED ALWAYS AS (VERIFY_ICO(ICO)) VIRTUAL,
    CONSTRAINT check_ICO CHECK(ICO_valid = 1),
    CONSTRAINT check_DIC CHECK(DIC = CONCAT('CZ', ICO)),

    CONSTRAINT fk_externy_zamestnanec
    FOREIGN KEY (ID_zamestnanca)
    REFERENCES zamestnanec(ID_zamestnanca)
    ON DELETE CASCADE
);


CREATE TABLE vlastny_zamestnanec (
    ID_zamestnanca NUMBER(8) PRIMARY KEY,
    Cislo_zdravotneho_preukazu VARCHAR(32),
    Datum_narodenia DATE NOT NULL,
    Plat_hod NUMBER(8) NOT NULL, -- Predpokladá sa plat v CZK
    Uvazok VARCHAR2(16) NOT NULL,
    Platena_dovolenka_dni NUMBER NOT NULL,
    Neplatena_dovolenka_dni NUMBER NOT NULL,
    Ulica VARCHAR2(32) NOT NULL,
    Mesto VARCHAR2(32) NOT NULL,
    PSC VARCHAR(5) NOT NULL,
    Cislo_OP VARCHAR2(8) NOT NULL,
    Datum_nastupu DATE NOT NULL,
    Datum_ukoncenia DATE,

    CONSTRAINT Zm_check_PSC CHECK (REGEXP_LIKE(PSC, '\d{5}')),
    CONSTRAINT Zm_check_Cislo_OP CHECK (REGEXP_LIKE(Cislo_OP, '[A-Z]{2}\d{6}')),
    -- Číslo zdravotného preukazu nemá pevne daný formát keďže cudzincom je pridelené v inom formáte ako českým občanom
    CONSTRAINT Zm_check_Cislo_zdravotneho_preukazu CHECK (REGEXP_LIKE(Cislo_zdravotneho_preukazu, '^\d+$')),
    CONSTRAINT Zm_check_Plat_hod CHECK (Plat_hod > 0),
    CONSTRAINT Zm_check_Platena_dovolenka_dni CHECK (Platena_dovolenka_dni >= 0),
    CONSTRAINT Zm_check_Neplatena_dovolenka_dni CHECK (Neplatena_dovolenka_dni >= 0),

    nadriadeny NUMBER REFERENCES vlastny_zamestnanec(ID_zamestnanca)
    ON DELETE SET NULL,

    CONSTRAINT fk_vlastny_zamestnanec
    FOREIGN KEY (ID_zamestnanca)
    REFERENCES zamestnanec(ID_zamestnanca)
    ON DELETE CASCADE
);

--
CREATE TABLE povereny_pracovnik(
    ID_zamestnanca NUMBER(8) PRIMARY KEY,

    CONSTRAINT fk_povereny_zamestnanec
    FOREIGN KEY (ID_zamestnanca)
    REFERENCES vlastny_zamestnanec(ID_zamestnanca)
    ON DELETE CASCADE
);

-------------------------------------------

CREATE TABLE pracuje (
    Cislo_objednavky NUMBER(8) NOT NULL,
    ID_zamestnanca NUMBER(8) NOT NULL,
    Datum_od DATE NOT NULL,
    Datum_do DATE,
    Druh_prace VARCHAR2(500) NOT NULL,

    PRIMARY KEY(Cislo_objednavky, ID_zamestnanca),
    CONSTRAINT fk_objednavka FOREIGN KEY (Cislo_objednavky)
    REFERENCES objednavka(Cislo_objednavky)
    ON DELETE CASCADE,

    CONSTRAINT fk_preukaz FOREIGN KEY (ID_zamestnanca)
    REFERENCES zamestnanec(ID_zamestnanca)
    ON DELETE CASCADE
);


CREATE TABLE vyplatna_listina (
    Datum DATE PRIMARY KEY,
    Odrobenych_hod NUMBER(5),
    Mzda NUMBER,
    Platena_dovolenka NUMBER(2),
    Neplatena_dovolenka NUMBER(2),
    Financne_odmeny NUMBER(8),

    ID_zamestnanca NUMBER(8) NOT NULL,
    CONSTRAINT fk_listina_zamestnanec FOREIGN KEY (ID_zamestnanca)
    REFERENCES zamestnanec(ID_zamestnanca)
    ON DELETE CASCADE
);


CREATE TABLE vybavenie (
    ID_vybavenia NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    Druh VARCHAR2(32) NOT NULL,
    Cena NUMBER NOT NULL,
    Stav VARCHAR2(500) NOT NULL,
    Datum_nakupu DATE NOT NULL,
    Nakupna_zmluva VARCHAR2(255),

    CONSTRAINT Vb_check_Cena CHECK (Cena >= 0),

    ID_zamestnanca NUMBER(8) NOT NULL,
    CONSTRAINT fk_vybavenie_zamestnanec FOREIGN KEY (ID_zamestnanca)
    REFERENCES povereny_pracovnik(ID_zamestnanca)
    ON DELETE SET NULL
);


CREATE TABLE material (
    ID_objednavky NUMBER(8) GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    Cislo_objednavky NUMBER(8) NOT NULL,
    ID_zamestnanca NUMBER(8) NOT NULL,
    Druh VARCHAR2(32) NOT NULL,
    Mnozstvo NUMBER NOT NULL,
    Jednotka VARCHAR2(16) NOT NULL,
    Cena NUMBER NOT NULL,
    Dodavatel VARCHAR2(32),
    Datum DATE NOT NULL,
    Nakupna_zmluva VARCHAR2(255), -- Cesta k súboru

    CONSTRAINT Mt_check_Cena CHECK (Cena >= 0),

    CONSTRAINT fk_material_objednavka FOREIGN KEY (Cislo_objednavky)
    REFERENCES objednavka(Cislo_objednavky)
    ON DELETE CASCADE,

    CONSTRAINT fk_material_pracovnik FOREIGN KEY (ID_zamestnanca)
    REFERENCES povereny_pracovnik(ID_zamestnanca)
    ON DELETE CASCADE
);

-------------------
-- Ukážkové dáta --
-------------------

INSERT INTO zakaznik(Priezvisko, Meno, Titul, Tel, Email, Ulica, Mesto, PSC)
VALUES ('Kopernik', 'Mikuláš', 'Ing.', '+421 906 452 987', 'kopernik@mail.com', 'Božetěchova', 'Brno', '60200');

INSERT INTO objednavka(Ulica, Mesto, PSC, Zaciatok_vystavby, Ukoncenie_vystavby, Popis, Status, Posledna_uprava, Specifikacia, ID_zakaznik)
VALUES ('Metodejova', 'Brno', '60200', TO_DATE('2023-07-30', 'yyyy/mm/dd'), NULL, 'Stavba rodinného domu', 'Nezačatá', NULL, '/home/objednavky/1/spec.pdf', 1);

INSERT INTO objednavka(Ulica, Mesto, PSC, Zaciatok_vystavby, Ukoncenie_vystavby, Popis, Status, Posledna_uprava, Specifikacia, ID_zakaznik)
VALUES ('Karlova', 'Praha', '60200', TO_DATE('2019-03-15', 'yyyy/mm/dd'), NULL, 'Stavba parku', 'Začatá', NULL, '/home/objednavky/2/spec.pdf', 1);

INSERT INTO objednavka(Ulica, Mesto, PSC, Zaciatok_vystavby, Ukoncenie_vystavby, Popis, Status, Posledna_uprava, Specifikacia, ID_zakaznik)
VALUES ('Křenova', 'Brno', '60200', TO_DATE('2014-04-03', 'yyyy/mm/dd'), TO_DATE('2017-09-04', 'yyyy/mm/dd'), 'Prerábanie strechy', 'Skončená', NULL, '/home/objednavky/3/spec.pdf', 1);

INSERT INTO zamestnanec(Priezvisko, Meno, Titul, Specializacia, Tel, Email, Cislo_uctu)
VALUES ('Newton', 'Isac', 'Ing.', 'Statik', '+421907442954', 'newton@mail.com', '0000111333/2700');
INSERT INTO externy_zamestnanec(ICO, DIC, Nazov_firmy, ID_zamestnanca)
VALUES ('25596641', 'CZ25596641', 'Stavmont', '1');

INSERT INTO zamestnanec(Priezvisko, Meno, Titul, Specializacia, Tel, Email, Cislo_uctu)
VALUES ('Tesla', 'Nicola', 'Ing.', 'Elektrika', '775442954', 'tesla@mail.com', '86-0199488014/0300');
INSERT INTO vlastny_zamestnanec(Cislo_zdravotneho_preukazu, Datum_narodenia, Plat_hod, Uvazok, Platena_dovolenka_dni, Neplatena_dovolenka_dni, Ulica, Mesto, PSC, Cislo_OP, Datum_nastupu, Datum_ukoncenia, nadriadeny, ID_zamestnanca)
VALUES ('1265421369', TO_DATE('1972-07-30', 'yyyy/mm/dd'), 200, 'Plný', 30, 45, 'Česká', 'Brno', '60200', 'HK123654', TO_DATE('1972-07-30', 'yyyy/mm/dd'), NULL, NULL, 2);

INSERT INTO zamestnanec(Priezvisko, Meno, Titul, Specializacia, Tel, Email, Cislo_uctu)
VALUES ('Einstein', 'Albert', 'Ing.', 'Statik', '595242654', 'einstein@mail.com', '86-0199488014/0300');
INSERT INTO vlastny_zamestnanec(Cislo_zdravotneho_preukazu, Datum_narodenia, Plat_hod, Uvazok, Platena_dovolenka_dni, Neplatena_dovolenka_dni, Ulica, Mesto, PSC, Cislo_OP, Datum_nastupu, Datum_ukoncenia, nadriadeny, ID_zamestnanca)
VALUES ('1265421369', TO_DATE('1988-05-14', 'yyyy/mm/dd'), 250, 'Plny', 30, 45, 'Mendelova', 'Brno', '06484', 'HK123987', TO_DATE('2000-02-09', 'yyyy/mm/dd'), NULL, NULL, 3);

INSERT INTO zamestnanec(Priezvisko, Meno, Titul, Specializacia, Tel, Email, Cislo_uctu)
VALUES ('Curie', 'Marie', 'Ing.', 'Referentka', '591232654', 'curie@mail.com', '86-0199488014/0300');
INSERT INTO vlastny_zamestnanec(Cislo_zdravotneho_preukazu, Datum_narodenia, Plat_hod, Uvazok, Platena_dovolenka_dni, Neplatena_dovolenka_dni, Ulica, Mesto, PSC, Cislo_OP, Datum_nastupu, Datum_ukoncenia, nadriadeny, ID_zamestnanca)
VALUES ('1265421369', TO_DATE('1985-11-17', 'yyyy/mm/dd'), 180, 'Plný', 30, 45, 'Berkova', 'Brno', '06484', 'HK125987', TO_DATE('2001-06-07', 'yyyy/mm/dd'), NULL, 3, 4);

INSERT INTO povereny_pracovnik(ID_zamestnanca)
VALUES (2);

INSERT INTO povereny_pracovnik(ID_zamestnanca)
VALUES (3);

INSERT INTO pracuje(Datum_od, Datum_do, Druh_prace, Cislo_objednavky, ID_zamestnanca)
VALUES (TO_DATE('1972-07-30', 'yyyy/mm/dd'), NULL, 'Stavbyvedúci', 1, 2);

INSERT INTO pracuje(Datum_od, Datum_do, Druh_prace, Cislo_objednavky, ID_zamestnanca)
VALUES (TO_DATE('1972-07-30', 'yyyy/mm/dd'), NULL, 'Stavbyvedúci', 2, 2);

INSERT INTO pracuje(Datum_od, Datum_do, Druh_prace, Cislo_objednavky, ID_zamestnanca)
VALUES (TO_DATE('1972-07-30', 'yyyy/mm/dd'), NULL, 'Stavbyvedúci', 3, 3);

INSERT INTO pracuje(Datum_od, Datum_do, Druh_prace, Cislo_objednavky, ID_zamestnanca)
VALUES (TO_DATE('1972-07-30', 'yyyy/mm/dd'), NULL, 'Referent', 1, 4);

-- Pri vytvorení výplatnej pásky na začiatku mesiaca nie sú známe údaje ako odpracované hodiny, atď.
-- Tie sa zadávajú a upravujú priebežne počas mesiaca
INSERT INTO vyplatna_listina(Datum, Odrobenych_hod, Mzda, Platena_dovolenka, Neplatena_dovolenka, Financne_odmeny, ID_zamestnanca)
VALUES (TO_DATE('1972-07', 'yyyy/mm'), NULL, NULL, NULL, NULL, NULL, 2);

INSERT INTO vybavenie(Druh, Cena, Stav, Datum_nakupu, Nakupna_zmluva, ID_zamestnanca)
VALUES ('Bager', '6000000', 'Nový', TO_DATE('1972-07-30', 'yyyy/mm/dd'), 'tu', '2');

INSERT INTO vybavenie(Druh, Cena, Stav, Datum_nakupu, Nakupna_zmluva, ID_zamestnanca)
VALUES ('Bager', '5500000', 'Nový', TO_DATE('2000-07-30', 'yyyy/mm/dd'), 'tu', '2');

INSERT INTO vybavenie(Druh, Cena, Stav, Datum_nakupu, Nakupna_zmluva, ID_zamestnanca)
VALUES ('Zbíjačka', '5000', 'Nový', TO_DATE('2001-07-30', 'yyyy/mm/dd'), 'tu', '3');

INSERT INTO material(Druh, Mnozstvo, Jednotka, Cena, Dodavatel, Datum, Nakupna_zmluva, Cislo_objednavky, ID_zamestnanca)
VALUES ('Tehly', '20', 't', 22000, 'BOUMIT', TO_DATE('1972-07-30', 'yyyy/mm/dd'), '/home/objednavky/1/materialy/tehly_boumit/2343242.pdf', '1', '2');

INSERT INTO material(Druh, Mnozstvo, Jednotka, Cena, Dodavatel, Datum, Nakupna_zmluva, Cislo_objednavky, ID_zamestnanca)
VALUES ('Tehly', '25', 't', 22500, 'BOUMIT', TO_DATE('2021-09-06', 'yyyy/mm/dd'), '/home/objednavky/2/materialy/tehly_boumit/2343243.pdf', '2', '2');

INSERT INTO material(Druh, Mnozstvo, Jednotka, Cena, Dodavatel, Datum, Nakupna_zmluva, Cislo_objednavky, ID_zamestnanca)
VALUES ('Okná', '24', 'ks', 1000, 'GlasMont', TO_DATE('2022-08-22', 'yyyy/mm/dd'), '/home/objednavky/1/materialy/okna/2343244.pdf', '1', '2');

INSERT INTO material(Druh, Mnozstvo, Jednotka, Cena, Dodavatel, Datum, Nakupna_zmluva, Cislo_objednavky, ID_zamestnanca)
VALUES ('Tehly', '5', 't', 500, 'BOUMIT', TO_DATE('2013-07-05', 'yyyy/mm/dd'), '/home/objednavky/1/materialy/tehly_boumit/2343245.pdf', '3', '3');

INSERT INTO material(Druh, Mnozstvo, Jednotka, Cena, Dodavatel, Datum, Nakupna_zmluva, Cislo_objednavky, ID_zamestnanca)
VALUES ('Cement', '2', 't', 250, 'BOUMIT', TO_DATE('2013-07-05', 'yyyy/mm/dd'), '/home/objednavky/1/materialy/cement/2343246.pdf', '3', '3');

-------------------
----- Selekty -----
-------------------

-- Spojenie dvoch tabuliek
-- Aký materiál je pridelený objednávke číslo 1 (ID objednávky, druh, množstvo, jednotka, cena)
SELECT ID_objednavky, Druh, Mnozstvo, Jednotka, Cena FROM material NATURAL JOIN objednavka WHERE Cislo_objednavky = 1;

-- Ktorí zamestnanci kúpili pre firmu vybavenie drahšie ako 10 000 czk (ID, Meno, Priezvisko, cena nákupu)
SELECT DISTINCT ID_zamestnanca, Meno, Priezvisko FROM vybavenie NATURAL JOIN zamestnanec WHERE Cena > 10000;

-- Spojenie troch tabuliek --
-- Ktorí zamestnanci pracujú na objednáckach v meste 'Brno' (ID, Meno, Priezvisko)
SELECT DISTINCT ID_zamestnanca, Meno, Priezvisko FROM zamestnanec NATURAL JOIN pracuje NATURAL JOIN objednavka WHERE Mesto = 'Brno';

-- Použitie GROUP BY a agregačných funkcií
-- Aká je celková cena materiálu pre jednotlivé objednávky (Cislo_objednavky, Mesto, Ukoncenie_vystavby, cena materialu)
SELECT Cislo_objednavky, Mesto, Ukoncenie_vystavby, SUM(Cena) cena_materialu FROM objednavka NATURAL JOIN material GROUP BY Cislo_objednavky, Mesto, Ukoncenie_vystavby;

-- Na koľkých objednávkach pracujú jednotliví zamestnanci (ID, Meno, Priezvisko, počet)
SELECT ID_zamestnanca, Meno, Priezvisko, COUNT(Cislo_objednavky) pocet_objednavok FROM zamestnanec NATURAL LEFT JOIN pracuje GROUP BY ID_zamestnanca, Meno, Priezvisko;

-- predikát EXISTS
-- Ktorí zamestnanci pracovali aspoň na jednej objednávke
SELECT DISTINCT ID_zamestnanca, Meno, Priezvisko FROM zamestnanec WHERE EXISTS (SELECT ID_zamestnanca FROM pracuje WHERE zamestnanec.ID_zamestnanca = pracuje.ID_zamestnanca);

-- predikát IN
-- Ktorí zamestnanci bývaju v mestách, kde prebiehala práca aspoň na jednej objednávke
SELECT DISTINCT ID_zamestnanca, Meno, Priezvisko FROM zamestnanec NATURAL JOIN vlastny_zamestnanec WHERE Mesto IN (SELECT DISTINCT Mesto FROM objednavka);
--


-----------------------
------- mazanie -------
-----------------------

-- zmazanie tabuliek

DROP TABLE zakaznik CASCADE CONSTRAINTS;
DROP TABLE pracuje CASCADE CONSTRAINTS;
DROP TABLE vyplatna_listina CASCADE CONSTRAINTS;
DROP TABLE material CASCADE CONSTRAINTS;
DROP TABLE povereny_pracovnik CASCADE CONSTRAINTS;
DROP TABLE vlastny_zamestnanec CASCADE CONSTRAINTS;
DROP TABLE vybavenie CASCADE CONSTRAINTS;
DROP TABLE externy_zamestnanec CASCADE CONSTRAINTS;
DROP TABLE objednavka CASCADE CONSTRAINTS;
DROP TABLE zamestnanec CASCADE CONSTRAINTS;

-- zmazanie sekvencií

DROP SEQUENCE var_symbol_seq;


-- Koniec súboru --
