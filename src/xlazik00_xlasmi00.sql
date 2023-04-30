/**
* Súbor: xlazik00_xlasmi00.sql
* Autori: Adam Lazík (xlazik00), Michal Ľaš (xlasmi00)
* Dátum: 26.03.2023
*/



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

DROP MATERIALIZED VIEW aktualne_prace;

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
----- Triggery ----
-------------------

-- V prípade ak ja upravený dátum kolaudácie na iný než NULL (teda je zadaný dátum kolaudáciu), tak pre všetky polia v tabuľke 'pracuje' pre danú zakázku nastav 'Datum_do' na daný dátum kolaudácie
CREATE OR REPLACE TRIGGER update_datum_prace
AFTER UPDATE OF Ukoncenie_vystavby ON objednavka
FOR EACH ROW
BEGIN
  IF :new.Ukoncenie_vystavby IS NOT NULL THEN
    UPDATE pracuje
    SET Datum_do =: new.Ukoncenie_vystavby
    WHERE Cislo_objednavky =: new.Cislo_objednavky
    AND Datum_do IS NULL;
  END IF;
END;
/

-- V pripade, ze je znamy datum ukoncenia pracovneho pomeru zamestnanca, nastavi sa tento datum ako datum ukoncenia jeho prace na objednavke, na ktorej prave pracuje
-- (a na ktorej datum jeho ukoncenia nebol pred touto udalostou znamy)
CREATE OR REPLACE TRIGGER update_ukoncenie_zamestnania
AFTER UPDATE OF Datum_ukoncenia ON vlastny_zamestnanec
FOR EACH ROW
BEGIN
    UPDATE pracuje
    SET Datum_do =: new.Datum_ukoncenia
    WHERE ID_Zamestnanca =: new.ID_Zamestnanca AND Datum_do IS NULL;
END;
/

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
VALUES ('Tesla', 'Nicola', 'Ing.', 'Statik', '775442954', 'tesla@mail.com', '86-0199488014/0300');
INSERT INTO vlastny_zamestnanec(Cislo_zdravotneho_preukazu, Datum_narodenia, Plat_hod, Uvazok, Platena_dovolenka_dni, Neplatena_dovolenka_dni, Ulica, Mesto, PSC, Cislo_OP, Datum_nastupu, Datum_ukoncenia, nadriadeny, ID_zamestnanca)
VALUES ('1265421369', TO_DATE('1951-07-30', 'yyyy/mm/dd'), 200, 'Plný', 30, 45, 'Česká', 'Brno', '60200', 'HK123654', TO_DATE('1969-07-30', 'yyyy/mm/dd'), NULL, NULL, 2);

INSERT INTO zamestnanec(Priezvisko, Meno, Titul, Specializacia, Tel, Email, Cislo_uctu)
VALUES ('Einstein', 'Albert', 'Ing.', 'Statik', '595242654', 'einstein@mail.com', '86-0199488014/0300');
INSERT INTO vlastny_zamestnanec(Cislo_zdravotneho_preukazu, Datum_narodenia, Plat_hod, Uvazok, Platena_dovolenka_dni, Neplatena_dovolenka_dni, Ulica, Mesto, PSC, Cislo_OP, Datum_nastupu, Datum_ukoncenia, nadriadeny, ID_zamestnanca)
VALUES ('1265421369', TO_DATE('1950-05-14', 'yyyy/mm/dd'), 250, 'Plny', 30, 45, 'Mendelova', 'Brno', '06484', 'HK123987', TO_DATE('1970-02-09', 'yyyy/mm/dd'), NULL, NULL, 3);

INSERT INTO zamestnanec(Priezvisko, Meno, Titul, Specializacia, Tel, Email, Cislo_uctu)
VALUES ('Curie', 'Marie', 'Ing.', 'Referentka', '591232654', 'curie@mail.com', '86-0199488014/0300');
INSERT INTO vlastny_zamestnanec(Cislo_zdravotneho_preukazu, Datum_narodenia, Plat_hod, Uvazok, Platena_dovolenka_dni, Neplatena_dovolenka_dni, Ulica, Mesto, PSC, Cislo_OP, Datum_nastupu, Datum_ukoncenia, nadriadeny, ID_zamestnanca)
VALUES ('1265421369', TO_DATE('1960-11-17', 'yyyy/mm/dd'), 180, 'Plný', 30, 45, 'Berkova', 'Brno', '06484', 'HK125987', TO_DATE('1977-06-07', 'yyyy/mm/dd'), NULL, 3, 4);

INSERT INTO povereny_pracovnik(ID_zamestnanca)
VALUES (2);

INSERT INTO povereny_pracovnik(ID_zamestnanca)
VALUES (3);

INSERT INTO pracuje(Datum_od, Datum_do, Druh_prace, Cislo_objednavky, ID_zamestnanca)
VALUES (TO_DATE('1972-07-30', 'yyyy/mm/dd'), TO_DATE('1988-03-04', 'yyyy/mm/dd'), 'Stavbyvedúci', 1, 2);

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

INSERT INTO vyplatna_listina(Datum, Odrobenych_hod, Mzda, Platena_dovolenka, Neplatena_dovolenka, Financne_odmeny, ID_zamestnanca)
VALUES (TO_DATE('1972-08', 'yyyy/mm'), 90, 24000, 0, 10, 0, 1);

INSERT INTO vyplatna_listina(Datum, Odrobenych_hod, Mzda, Platena_dovolenka, Neplatena_dovolenka, Financne_odmeny, ID_zamestnanca)
VALUES (TO_DATE('1972-09', 'yyyy/mm'), 120, 36000, 1, 3, 0, 3);

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



---------------------------
----- Priklad trigger -----
---------------------------

-- selekt na overenie
SELECT * FROM pracuje;

-- tento príkaz by mal vyvolať trigger a zmeniť atribút 'Datum_do', pri pracujúcich na konkrétnej objednávke, ktorí mali 'Datum_do' = NULL na dátum ukončenia čiže 2023-04-20
UPDATE objednavka
SET Ukoncenie_vystavby = TO_DATE('2023-04-20', 'yyyy/mm/dd')
WHERE Cislo_objednavky = 1;

UPDATE vlastny_zamestnanec
SET Datum_ukoncenia = TO_DATE('2023-06-20', 'YYYY-MM-DD')
WHERE ID_zamestnanca = 3;

-- selekt po prevedeni zmien
SELECT * FROM pracuje;

---------------------
----- Procedúry -----
---------------------

-- Procedúra vypočíta priemernú mzdu, platenú dovolenku, neplatenú dovolenku a odmeny za zadaný časový údaj 'od'-'do'

CREATE OR REPLACE PROCEDURE avg_vyplatna_listina(d_od IN DATE, d_do IN DATE)
AS
    avg_mzda NUMBER;
    avg_pl_dovolenka NUMBER;
    avg_npl_dovolenka NUMBER;
    avg_odmeny NUMBER;
    num_mzda NUMBER := 0;
    num_pl_dovolenka NUMBER := 0;
    num_npl_dovolenka NUMBER := 0;
    num_odmeny NUMBER := 0;
    num_zamestnanci NUMBER;
    CURSOR cursor_vyplatna_listina IS SELECT * FROM vyplatna_listina WHERE Datum BETWEEN d_od AND d_do;
    riadok_vyplatna_listina vyplatna_listina%ROWTYPE;
BEGIN

    OPEN cursor_vyplatna_listina;

    LOOP
        FETCH cursor_vyplatna_listina INTO riadok_vyplatna_listina;
        EXIT WHEN cursor_vyplatna_listina%NOTFOUND;

        IF riadok_vyplatna_listina.Mzda IS NOT NULL THEN
        num_mzda := num_mzda + riadok_vyplatna_listina.Mzda;
        END IF;

        IF riadok_vyplatna_listina.Platena_dovolenka IS NOT NULL THEN
        num_pl_dovolenka := num_pl_dovolenka + riadok_vyplatna_listina.Platena_dovolenka;
        END IF;

        IF riadok_vyplatna_listina.Neplatena_dovolenka IS NOT NULL THEN
        num_npl_dovolenka := num_npl_dovolenka + riadok_vyplatna_listina.Neplatena_dovolenka;
        END IF;

        IF riadok_vyplatna_listina.Financne_odmeny IS NOT NULL THEN
        num_odmeny := num_odmeny + riadok_vyplatna_listina.Financne_odmeny;
        END IF;

    END LOOP;

    CLOSE cursor_vyplatna_listina;

    SELECT COUNT(*) INTO num_zamestnanci FROM vlastny_zamestnanec WHERE Datum_nastupu <= d_od;

    -- výpočet priemerných hodnôt
    avg_mzda := num_mzda / num_zamestnanci;
    avg_pl_dovolenka := num_pl_dovolenka / num_zamestnanci;
    avg_npl_dovolenka := num_npl_dovolenka / num_zamestnanci;
    avg_odmeny := num_odmeny / num_zamestnanci;

    -- Výpis
    DBMS_OUTPUT.put_line
    (
       'V zadanom období bola celková vyplatená mzda '
        || num_mzda || '; celková hodnota vyplatených odmien '
        || num_odmeny || '; celkový počet zamestnancov '
        || num_zamestnanci || '.'
    );

    DBMS_OUTPUT.put_line(
		'Priemerná mzda za dané obdobie bola  '
		|| avg_mzda || '; priemerná doba neplatenej dovolenky na jedného zamestnanca bola '
		|| avg_pl_dovolenka || '; priemerná doba platenej dovolenky na jedného zamestnanca '
		|| avg_npl_dovolenka || '; priemerné odmeny vyplatené na jedného zamestnanca '
        || avg_odmeny || '.'
	);

    EXCEPTION WHEN ZERO_DIVIDE THEN
	BEGIN
		IF num_zamestnanci = 0 THEN
			DBMS_OUTPUT.put_line('V danom období neboli zamestnaní žiadni zamestnanci.');
		END IF;
	END;
END;
/

-- Procedúra spočíta celkové náklady za zadaný rok (platy zamestnancov + financne odmeny + cenu zakúpeného vybavenia + cenu zakupeneho materialu)
CREATE OR REPLACE PROCEDURE rocne_vydaje_total(rok IN VARCHAR2)
AS
    suma_vl NUMBER := 0;
    suma_vb NUMBER := 0;
    suma_m NUMBER := 0;
    suma_total NUMBER := 0;
BEGIN
    SELECT NVL(SUM(Mzda + Financne_odmeny), 0) INTO suma_vl FROM vyplatna_listina WHERE TO_CHAR(Datum, 'YYYY') = rok;
    SELECT NVL(SUM(Cena), 0) INTO suma_vb FROM vybavenie WHERE TO_CHAR(Datum_nakupu, 'YYYY') = rok;
    SELECT NVL(SUM(Cena), 0) INTO suma_m FROM material WHERE  TO_CHAR(Datum, 'YYYY') = rok;
    suma_total := suma_vl + suma_vb + suma_m;

    DBMS_OUTPUT.put_line('Totalne vydaje za rok ' || rok || ':');
    DBMS_OUTPUT.put_line('Vyplatne listiny: ' || suma_vl);
    DBMS_OUTPUT.put_line('Material: ' || suma_m);
    DBMS_OUTPUT.put_line('Vybavenie: ' || suma_vb);
    DBMS_OUTPUT.put_line('Celkovo: ' || suma_total);
END;
/
-- Príklad spustenia
SET SERVEROUTPUT ON;
EXECUTE avg_vyplatna_listina(DATE '1971-07-05', DATE '1973-07-05');
EXECUTE rocne_vydaje_total('1972');

------------------------
----- EXPLAIN PLAN -----
------------------------

-- Ktorí zamestnanci majú špecializáciu 'Statik' a pracovali na viac ako jednej objednávke + koľko ich je

EXPLAIN PLAN FOR
SELECT Priezvisko, Meno, Titul, COUNT(*) FROM pracuje NATURAL JOIN zamestnanec WHERE Specializacia = 'Statik' GROUP BY Priezvisko, Meno, Titul HAVING COUNT(*) > 1;

-- INDEX
CREATE INDEX zamestnanec_spec ON zamestnanec (Specializacia);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

EXPLAIN PLAN FOR
SELECT Priezvisko, Meno, Titul, COUNT(*) FROM pracuje NATURAL JOIN zamestnanec WHERE Specializacia = 'Statik' GROUP BY Priezvisko, Meno, Titul HAVING COUNT(*) > 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

----------------------------
----- Prístupové práva -----
----------------------------


GRANT ALL PRIVILEGES ON  pracuje TO xlasmi00;
GRANT ALL PRIVILEGES ON  zamestnanec TO xlasmi00;

-----------------------------
----- MATERIALIZED VIEW -----
-----------------------------

-- Vyber vsetc
CREATE MATERIALIZED VIEW aktualne_prace
BUILD IMMEDIATE
AS
SELECT Id_Zamestnanca, Priezvisko, Meno, Cislo_Objednavky, Datum_od FROM xlazik00.zamestnanec NATURAL JOIN xlazik00.pracuje
WHERE Datum_do IS NULL OR Datum_do > TRUNC(SYSDATE);


SELECT * FROM aktualne_prace;
-- TODO select
-- TODO použitie
-- TODO update

----------------------------
--------- Selekty ----------
----------------------------

-- Selekt roztriedi objednavky materialu, ktore sa meraju v tonach, do skupin podla objednanej vahy
WITH objednavky_materialu AS (SELECT Id_Objednavky, Druh, Dodavatel, Cena, Mnozstvo, Dodavatel FROM material NATURAL JOIN objednavka WHERE Jednotka = 't') SELECT
Id_Objednavky,
Druh,
CASE
    WHEN Mnozstvo < 10 THEN 'Mala objednavka'
    WHEN Mnozstvo BETWEEN 10 and 20 THEN 'Stredna objednavka'
    ELSE 'Velka objednavka'
END AS Rozsah_Objednavky
FROM objednavky_materialu;

-- Koniec súboru --
