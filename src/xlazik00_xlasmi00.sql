/**
* File: xlazik00_xlasmi00
* Authors: Adam Lazík (xlazik00), Michal Ľaš (xlasmi00)
* Brief: SQL script for IDS project 2
* Date: 19.03.2023
*
*/


-------------------------
-- vytvaranie tabuliek --
-------------------------


CREATE TABLE zakaznik (
    ID_zakaznik NUMBER(10) GENERATED ALWAYS PRIMARY KEY,
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
    cislo_objednavky NUMBER GENERATED ALWAYS PRIMARY KEY,
    Ulica VARCHAR2(32) NOT NULL,
    Mesto VARCHAR2(32) NOT NULL,
    PSC NUMBER(5) NOT NULL,
    zaciatok_vystavby DATE,
    ukoncenie_vystavby DATE,
    Popis VARCHAR2(500),
    Status VARCHAR2(16),
    posledna_uprava DATE,
    Specifikacia VARCHAR2(255),
    
    CONSTRAINT fk_objednavka_zakaznik FOREIGN KEY (ID_zakaznik) 
    REFERENCES zakaznik(ID_zakaznik)
    ON DELETE SET NULL
);


CREATE TABLE material (
    ID_objednavky NUMBER GENERATED ALWAYS PRIMARY KEY,
    cislo_objednavky NUMBER NOT NULL,
    Druh VARCHAR2(32) NOT NULL,
    Mnozstvo NUMBER NOT NULL,
    Jednotka VARCHAR2 NOT NULL,
    Cena NUMBER NOT NULL,
    Dodávateľ VARCHAR2(32),
    Datum DATE NOT NULL,
    nakupna_zmluva VARCHAR2(255),
    
    CONSTRAINT fk_material_objednavka FOREIGN KEY (cislo_objednavky) 
    REFERENCES objednavka(cislo_objednavky)
    ON DELETE CASCADE,
    
    CONSTRAINT fk_material_pracovnik FOREIGN KEY (cislo_zdravotneho_preukazu) 
    REFERENCES povereny_pracovnik(cislo_zdravotneho_preukazu)
    ON DELETE CASCADE
);


-- externy zamestanec pracuje --
CREATE TABLE ex_pracuje (
    cislo_objednavky NUMBER NOT NULL,
    ICO NUMBER(8) NOT NULL,
    datum_od DATE NOT NULL,
    datum_do DATE,
    druh_prace VARCHAR2(500) NOT NULL,
    Cena NUMBER NOT NULL,
    PRIMARY KEY(cislo_objednavky, ICO), 
    CONSTRAINT fk_objednavka FOREIGN KEY (cislo_objednavky) REFERENCES objednavka(cislo_objednavky) 
    ON DELETE CASCADE,
    CONSTRAINT fk_ICO FOREIGN KEY (ICO) REFERENCES externy_zamestnanec(ICO) 
    ON DELETE CASCADE
    
);


CREATE TABLE externy_zamestnanec (
    ICO NUMBER(8) PRIMARY KEY, -- TODO: CHECK --
    DIC VARCHAR2(16) NOT NULL,
    Priezvisko VARCHAR2(32) NOT NULL,
    Meno VARCHAR2(32) NOT NULL,
    Titul VARCHAR2(32),
    nazov_firmy VARCHAR2(64) NOT NULL,
    Specializacia VARCHAR2(64) NOT NULL,
    cislo_uctu NUMBER(16) NOT NULL,  -- TODO: CHECK --
    var_symbol NUMBER(8) GENERATED ALWAYS NOT NULL,
    Tel NUMBER(10) NOT NULL,
    Email VARCHAR2(32) NOT NULL
);


CREATE TABLE vlastny_zamestnanec (
    cislo_zdravotneho_preukazu NUMBER PRIMARY KEY, -- TODO: NUMBER(?), CHECK --
    Priezvisko VARCHAR2(32) NOT NULL,
    Meno VARCHAR2(32) NOT NULL,
    Titul VARCHAR2(32),
    datum_narodenia DATE NOT NULL,
    Specializacia VARCHAR2(64) NOT NULL,
    Tel NUMBER(10) NOT NULL,
    Email VARCHAR2(32) NOT NULL,
    plat_hod NUMBER(8) NOT NULL,
    cislo_uctu NUMBER(16) NOT NULL,  -- TODO: CHECK --
    var_symbol NUMBER(8) GENERATED ALWAYS NOT NULL,
    Uvazok VARCHAR2(16) NOT NULL,
    dovolenka_dni NUMBER NOT NULL,
    Ulica VARCHAR2(32) NOT NULL,
    Mesto VARCHAR2(32) NOT NULL,
    PSC NUMBER(5) NOT NULL,
    cislo_OP VARCHAR2(8) NOT NULL,
    datum_nastupu DATE NOT NULL,
    datum_ukoncenia DATE NOT NULL,
    
    nadriadeny NUMBER REFERENCES vlastny_zamestnanec(cislo_zdravotneho_preukazu)
    ON DELETE SET NULL
);


-- interny zamestanec pracuje --
CREATE TABLE in_pracuje (
    cislo_objednavky NUMBER NOT NULL,
    cislo_zdravotneho_preukazu NUMBER NOT NULL,-- TODO: NUMBER(?) --
    datum_od DATE NOT NULL,
    datum_do DATE,
    druh_prace VARCHAR2(500) NOT NULL,
    PRIMARY KEY(cislo_objednavky, cislo_zdravotneho_preukazu), 
    CONSTRAINT fk_objednavka FOREIGN KEY (cislo_objednavky) REFERENCES objednavka(cislo_objednavky) 
    ON DELETE CASCADE,
    CONSTRAINT fk_preukaz FOREIGN KEY (cislo_zdravotneho_preukazu) REFERENCES vlastny_zamestnanec(cislo_zdravotneho_preukazu) 
    ON DELETE CASCADE
);


CREATE TABLE vyplatna_listina (
    datum DATE DEFAULT TRUNC(SYSDATE, 'MM') PRIMARY KEY,
    odrobenych_hod NUMBER(5) NOT NULL,
    mzda NUMBER NOT NULL,
    platena_dovolenka NUMBER(2),
    neplatena_dovolenka NUMBER(2),
    financne_odmeny NUMBER(8),
    
    CONSTRAINT fk_listina_zamestnanec FOREIGN KEY (cislo_zdravotneho_preukazu)
    REFERENCES vlastny_zamestnanec(cislo_zdravotneho_preukazu)
    ON DELETE CASCADE
);


CREATE TABLE vybavenie (
    ID_vybavenia NUMBER GENERATED ALWAYS PRIMARY KEY,
    Druh VARCHAR2(32) NOT NULL,
    Cena NUMBER NOT NULL,
    Stav VARCHAR2(500) NOT NULL,
    datum_nakupu DATE NOT NULL,
    nakupna_zmluva VARCHAR2(255),
    
    CONSTRAINT fk_vybavenie_zamestnanec FOREIGN KEY (cislo_zdravotneho_preukazu)
    REFERENCES povereny_pracovnik(cislo_zdravotneho_preukazu)
    ON DELETE SET NULL
);


CREATE TABLE povereny_pracovnik(
    CONSTRAINT fk_povereny_zamestnanec
    FOREIGN KEY (cislo_zdravotneho_preukazu)
    REFERENCES vlastny_zamestnanec(cislo_zdravotneho_preukazu)
    ON DELETE CASCADE
);

-------------------
-- ukazkove data --
-------------------

-- TODO --

-----------------------
-- zmazanie tabuliek --
-----------------------

DROP TABLE zakaznik;
DROP TABLE objednavka;
DROP TABLE material;
DROP TABLE ex_pracuje;
DROP TABLE externy_zamestnanec;
DROP TABLE vlastny_zamestnanec;
DROP TABLE in_pracuje;
DROP TABLE vyplatna_listina;
DROP TABLE povereny_pracovnik;

-- konec suboru --