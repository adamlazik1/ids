/**
* File: xlazik00_xlasmi00.sql
* Authors: Adam Lazík (xlazik00), Michal Ľaš (xlasmi00)
* Brief: SQL script for IDS project 2
* Date: 19.03.2023
*
*/

-- TODO: CHECKs (napr. hodnoty ktory by nemali byt < 0, datumy aby sedeli, ...)
-- TODO: pri 'cislo_zdravotneho_preukazu' doplnit max dlzku
-- TODO: upravit inserty (len nech su krajsie a zmysluplnejsie)


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

-- zmazanie seqvencii

DROP SEQUENCE var_symbol_seq;
DROP SEQUENCE zakaznik_seq;


-------------------------
-- vytvaranie seqvecii --
-------------------------

CREATE SEQUENCE var_symbol_seq
START WITH 10000000
INCREMENT BY 1
MAXVALUE 99999999
NOCACHE
NOCYCLE;


CREATE SEQUENCE zakaznik_seq
START WITH 1
INCREMENT BY 1;
  
-------------------------
-- vytvaranie tabuliek --
-------------------------


CREATE TABLE zakaznik (
    ID_zakaznik NUMBER(10) DEFAULT zakaznik_seq.NEXTVAL PRIMARY KEY,
    Priezvisko VARCHAR2(32) NOT NULL,
    Meno VARCHAR2(32) NOT NULL,
    Titul VARCHAR2(32),
    Tel NUMBER(10) NOT NULL,
    Email VARCHAR2(32) NOT NULL,
    Ulica VARCHAR2(32) NOT NULL,
    Mesto VARCHAR2(32) NOT NULL,
    PSC NUMBER(5) NOT NULL
);


CREATE TABLE objednavka (
    cislo_objednavky NUMBER(8) GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    Ulica VARCHAR2(32) NOT NULL,
    Mesto VARCHAR2(32) NOT NULL,
    PSC NUMBER(5) NOT NULL,
    zaciatok_vystavby DATE,
    ukoncenie_vystavby DATE,
    Popis VARCHAR2(500),
    Status VARCHAR2(16),
    posledna_uprava DATE,
    Specifikacia VARCHAR2(255),
    
    ID_zakaznik NUMBER(10) NOT NULL,
    CONSTRAINT fk_objednavka_zakaznik FOREIGN KEY (ID_zakaznik) 
    REFERENCES zakaznik(ID_zakaznik)
    ON DELETE SET NULL
);


-------------------------------------------
-- Generalizacia/Specializacia
-- nadtyp (zamestnanec) + podtyp (externy_zamestnanec) + podtyp (vlastny_zamestnanec)
-- nadtyp (vlastny_zamestnanec) + podtyp (povereny_pracovnik)
-- podtypy obsahuju primarny kluc natypu

CREATE TABLE zamestnanec (
    ID_zamestnanca NUMBER(8) GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    Priezvisko VARCHAR2(32) NOT NULL,
    Meno VARCHAR2(32) NOT NULL,
    Titul VARCHAR2(32),
    Specializacia VARCHAR2(64) NOT NULL,
    Tel NUMBER(10) NOT NULL,
    Email VARCHAR2(32) NOT NULL,
    cislo_uctu NUMBER(16) NOT NULL,  -- TODO: CHECK --
    var_symbol NUMBER(8) DEFAULT var_symbol_seq.NEXTVAL
);


CREATE TABLE externy_zamestnanec (
    ID_zamestnanca NUMBER(8) PRIMARY KEY,
    ICO NUMBER(8), -- TODO: CHECK --
    DIC VARCHAR2(16) NOT NULL,
    nazov_firmy VARCHAR2(64) NOT NULL,
    
    CONSTRAINT fk_externy_zamestnanec
    FOREIGN KEY (ID_zamestnanca)
    REFERENCES zamestnanec(ID_zamestnanca)
    ON DELETE CASCADE
);


CREATE TABLE vlastny_zamestnanec (
    ID_zamestnanca NUMBER(8) PRIMARY KEY,
    cislo_zdravotneho_preukazu NUMBER, -- TODO: NUMBER(?), CHECK --
    datum_narodenia DATE NOT NULL,
    plat_hod NUMBER(8) NOT NULL,
    Uvazok VARCHAR2(16) NOT NULL,
    dovolenka_dni NUMBER NOT NULL,
    Ulica VARCHAR2(32) NOT NULL,
    Mesto VARCHAR2(32) NOT NULL,
    PSC NUMBER(5) NOT NULL,
    cislo_OP VARCHAR2(8) NOT NULL,
    datum_nastupu DATE NOT NULL,
    datum_ukoncenia DATE,
    
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
    cislo_objednavky NUMBER(8) NOT NULL,
    ID_zamestnanca NUMBER(8) NOT NULL,
    datum_od DATE NOT NULL,
    datum_do DATE,
    druh_prace VARCHAR2(500) NOT NULL,
    
    PRIMARY KEY(cislo_objednavky, ID_zamestnanca), 
    CONSTRAINT fk_objednavka FOREIGN KEY (cislo_objednavky)
    REFERENCES objednavka(cislo_objednavky) 
    ON DELETE CASCADE,
    
    CONSTRAINT fk_preukaz FOREIGN KEY (ID_zamestnanca)
    REFERENCES zamestnanec(ID_zamestnanca) 
    ON DELETE CASCADE
);


CREATE TABLE vyplatna_listina (
    Datum DATE DEFAULT TRUNC(SYSDATE, 'MM') PRIMARY KEY,
    odrobenych_hod NUMBER(5) NOT NULL,
    Mzda NUMBER NOT NULL,
    platena_dovolenka NUMBER(2),
    neplatena_dovolenka NUMBER(2),
    financne_odmeny NUMBER(8),
    
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
    datum_nakupu DATE NOT NULL,
    nakupna_zmluva VARCHAR2(255),
    
    ID_zamestnanca NUMBER(8) NOT NULL,
    CONSTRAINT fk_vybavenie_zamestnanec FOREIGN KEY (ID_zamestnanca)
    REFERENCES povereny_pracovnik(ID_zamestnanca)
    ON DELETE SET NULL
);


CREATE TABLE material (
    ID_objednavky NUMBER(8) GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cislo_objednavky NUMBER(8) NOT NULL,
    ID_zamestnanca NUMBER(8) NOT NULL,
    Druh VARCHAR2(32) NOT NULL,
    Mnozstvo NUMBER NOT NULL,
    Jednotka VARCHAR2(16) NOT NULL,
    Cena NUMBER NOT NULL,
    Dodavatel VARCHAR2(32),
    Datum DATE NOT NULL,
    nakupna_zmluva VARCHAR2(255),
    
    CONSTRAINT fk_material_objednavka FOREIGN KEY (cislo_objednavky) 
    REFERENCES objednavka(cislo_objednavky)
    ON DELETE CASCADE,
    
    CONSTRAINT fk_material_pracovnik FOREIGN KEY (ID_zamestnanca) 
    REFERENCES povereny_pracovnik(ID_zamestnanca)
    ON DELETE CASCADE
);

-------------------
-- ukazkove data --
-------------------

INSERT INTO zakaznik(Priezvisko, Meno, Titul, Tel, Email, Ulica, Mesto, PSC)
VALUES ('Kopernik', 'Mikulas', 'Ing.', '0906452987', 'kopernik@mail.com', 'Bozechtova', 'Brno', '05247');

INSERT INTO objednavka(Ulica, Mesto, PSC, zaciatok_vystavby, ukoncenie_vystavby, Popis, Status, posledna_uprava, Specifikacia, ID_zakaznik)
VALUES ('Metodejova', 'Brno', '06484', TO_DATE('1972-07-30', 'yyyy/mm/dd'), NULL, NULL, NULL, NULL, NULL, 1);

INSERT INTO zamestnanec(Priezvisko, Meno, Titul, Specializacia, Tel, Email, cislo_uctu)
VALUES ('Newton', 'Isac', 'Ing.', 'Statik', '0907442954', 'newton@mail.com', '1456987634');
INSERT INTO externy_zamestnanec(ICO, DIC, nazov_firmy, ID_zamestnanca)
VALUES ('13649756', '456972136', 'Stavmont', '1');

INSERT INTO zamestnanec(Priezvisko, Meno, Titul, Specializacia, Tel, Email, cislo_uctu)
VALUES ('Tesla', 'Nicola', 'Ing.', 'Elektrika', '0907442954', 'tesla@mail.com', '1456987634');
INSERT INTO vlastny_zamestnanec(cislo_zdravotneho_preukazu, datum_narodenia, plat_hod, Uvazok, dovolenka_dni, Ulica, Mesto, PSC, cislo_OP, datum_nastupu, datum_ukoncenia, nadriadeny, ID_zamestnanca)
VALUES ('1265421369', TO_DATE('1972-07-30', 'yyyy/mm/dd'), '8', 'Plny', '30', 'Ceska', 'Brno', '02354', 'HK123654', TO_DATE('1972-07-30', 'yyyy/mm/dd'), NULL, NULL, '2');

INSERT INTO povereny_pracovnik(ID_zamestnanca)
VALUES (2);

INSERT INTO pracuje(datum_od, datum_do, druh_prace, cislo_objednavky, ID_zamestnanca)
VALUES (TO_DATE('1972-07-30', 'yyyy/mm/dd'), NULL, 'Stavbyveduci', '1', '2');

INSERT INTO vyplatna_listina(Datum, odrobenych_hod, Mzda, platena_dovolenka, neplatena_dovolenka, financne_odmeny, ID_zamestnanca)
VALUES (TO_DATE('1972-07', 'yyyy/mm'), '98', '1800', NULL, NULL, NULL, '2');

INSERT INTO vybavenie(Druh, Cena, Stav, datum_nakupu, nakupna_zmluva, ID_zamestnanca)
VALUES ('Bager', '6000', 'Novy', TO_DATE('1972-07-30', 'yyyy/mm/dd'), 'tu', '2');

INSERT INTO material(Druh, Mnozstvo, Jednotka, Cena, Dodavatel, Datum, nakupna_zmluva, cislo_objednavky, ID_zamestnanca)
VALUES ('Tehly', '20', 't', '600', 'BOUMIT', TO_DATE('1972-07-30', 'yyyy/mm/dd'), 'tu', '1', '2');


-------------------
-- vypis tabuliek -
-------------------

SELECT * FROM zakaznik;
SELECT * FROM objednavka;
SELECT * FROM zamestnanec;
SELECT * FROM externy_zamestnanec;
SELECT * FROM vlastny_zamestnanec;
SELECT * FROM povereny_pracovnik;
SELECT * FROM vyplatna_listina;
SELECT * FROM vybavenie;
SELECT * FROM material;


-- konec suboru --