/*create table Test(id integer, title varchar(100));
insert into Test(id, title) values(1, "Hello");
select * from Test; */
-- Your code here!
DROP DATABASE IF EXISTS SPONS_MANAGEMENT;
CREATE DATABASE SPONS_MANAGEMENT;
USE SPONS_MANAGEMENT;

CREATE TABLE Events(
event_id VARCHAR(10) NOT NULL PRIMARY KEY,
event_name VARCHAR(100),
event_desc VARCHAR(600),
event_type VARCHAR(20)
);

CREATE TABLE SponsorshipDetails(
event_id VARCHAR(10) NOT NULL PRIMARY KEY,
spons_requirement VARCHAR(500),
spons_amount DECIMAL(10, 2) NOT NULL,
spons_amount_curr DECIMAL(10,2),
FOREIGN KEY fk_SponsorshipDetailsEvent (event_id) REFERENCES Event(event_id) ON DELETE CASCADE
);

CREATE TABLE SponsorshipPayment(
spons_id VARCHAR(10) NOT NULL PRIMARY KEY,
spons_amount DECIMAL(10, 2) NOT NULL,
spons_type VARCHAR(20)
);

CREATE TABLE Alumni(
spons_id VARCHAR(10) NOT NULL,
spons_name VARCHAR(100),
pass_out_year INT,
total_spons_amount DECIMAL(10, 2) NOT NULL,
FOREIGN KEY fk_AlumniSponsPayment (spons_id) REFERENCES Sponsorship_Payment(spons_id) ON DELETE CASCADE
);

CREATE TABLE OtherSponsors(
spons_id VARCHAR(10) NOT NULL,
spons_name VARCHAR(100),
other_spons_type VARCHAR(20),
total_spons_amount DECIMAL(10,2) NOT NULL,
FOREIGN KEY fk_OtherSponsorsPayment (spons_id) REFERENCES Sponsorship_Payment(spons_id) ON DELETE CASCADE
);

CREATE TABLE PaymentDetails(
spons_id VARCHAR(10) NOT NULL,
event_id VARCHAR(10) NOT NULL,
s_amount DECIMAL(10, 2) NOT NULL,
reference_id VARCHAR(20) NOT NULL PRIMARY KEY, 
FOREIGN KEY fk_PaymentDetailsSponsorsPayment (spons_id) REFERENCES SponsorshipPayment(spons_id) ON DELETE CASCADE,
FOREIGN KEY fk_OtherSponsorsPayment (event_id) REFERENCES Event(event_id) ON DELETE CASCADE
);

CREATE TABLE Donations(
spons_id VARCHAR(10) NOT NULL,
d_reference_id VARCHAR(20) NOT NULL PRIMARY KEY,
s_amount DECIMAL(10, 2) NOT NULL,
FOREIGN KEY fk_PaymentDetailsSponsorsPayment (spons_id) REFERENCES SponsorshipPayment(spons_id) ON DELETE CASCADE
);

DELIMITER //
CREATE FUNCTION count_(string varchar(20), sponsid varchar(10))
RETURNS INT
BEGIN

    IF STRCMP(string, "Alumni") = 0
    then
        RETURN (SELECT count(*) from Alumni where spons_id=sponsid);
    end if;
    IF STRCMP(string, "OtherSponsors") = 0
    then
        RETURN (SELECT count(*) from OtherSponsors where spons_id=sponsid);
    end if;
    IF STRCMP(string, "SponsorshipPayment") = 0
    then
        RETURN (SELECT count(*) from SponsorshipPayment where spons_id=sponsid);
    end if;
    RETURN 0;
END; //
DELIMITER ;

delimiter //
CREATE TRIGGER update_spons_elements AFTER INSERT ON PaymentDetails For Each Row
BEGIN
    DECLARE r_count INT;
    DECLARE r1_count INT;
    DECLARE rsp_count INT;
    DECLARE t_s_a decimal(10,2);

    DECLARE idd varchar(10);
    DECLARE amount_ decimal(10,2);
    DECLARE type_ varchar(20);
    
    DECLARE Invalid_Spons_id CONDITION FOR SQLSTATE '02018';
    DECLARE CONTINUE HANDLER FOR Invalid_Spons_id
    RESIGNAL SET MESSAGE_TEXT = 'Invalid Spons_id. Check the spons_id correctly or insert the spons_id into the Alumni or OtherSponsors table. Incorrect:';
/*    
    select count(*) into r_count from Alumni where spons_id = NEW.spons_id;
    select count(*) into r1_count from OtherSponsors where spons_id = NEW.spons_id;
    select count(*) into rsp_count from SponsorshipPayment where spons_id = NEW.spons_id; */

    set r_count := count_("Alumni", NEW.spons_id);
    set r1_count := count_("OtherSponsors", NEW.spons_id);
    set rsp_count := count_("SponsorshipPayment", NEW.spons_id);

    if r_count > 0
    then
        set t_s_a := (SELECT total_spons_amount FROM Alumni where spons_id = NEW.spons_id);
        update Alumni set total_spons_amount = t_s_a + NEW.s_amount where Alumni.spons_id = NEW.spons_id;
        set t_s_a := (SELECT spons_amount_curr FROM SponsorshipDetails where event_id = NEW.event_id);
        update SponsorshipDetails set spons_amount_curr := t_s_a + NEW.s_amount where event_id = NEW.event_id;
        if rsp_count > 0
        then
            set t_s_a := (SELECT spons_amount FROM SponsorshipPayment where spons_id = NEW.spons_id);
            update SponsorshipPayment set spons_amount := t_s_a + NEW.s_amount where spons_id = NEW.spons_id;        
        else
            set idd := NEW.spons_id;
            set amount_ := NEW.s_amount;
            set type_ := "Alumni";
            INSERT INTO SponsorshipPayment(spons_id, spons_amount, spons_type) VALUES(idd, amount_, type_);
        end if;
    end if;
    if r1_count > 0
    then
        set t_s_a := (SELECT total_spons_amount FROM OtherSponsors where spons_id = NEW.spons_id);
        update OtherSponsors set total_spons_amount = t_s_a + NEW.s_amount where OtherSponsors.spons_id = NEW.spons_id;
        set t_s_a := (SELECT spons_amount_curr FROM SponsorshipDetails where event_id = NEW.event_id);
        update SponsorshipDetails set spons_amount_curr := t_s_a + NEW.s_amount where event_id = NEW.event_id;
        if rsp_count > 0
        then
            set t_s_a := (SELECT spons_amount FROM SponsorshipPayment where spons_id = NEW.spons_id);
            update SponsorshipPayment set spons_amount := t_s_a + NEW.s_amount where spons_id = NEW.spons_id;        
        else
            set idd := NEW.spons_id;
            set amount_ := NEW.s_amount;
            set type_ := "Sponsor";
            INSERT INTO SponsorshipPayment(spons_id, spons_amount, spons_type) VALUES(idd, amount_, type_);
        end if;
    end if;
    if r_count < 1 AND r1_count < 1
    then
        SIGNAL Invalid_Spons_id;
    end if;
END//
DELIMITER ;

delimiter //
CREATE TRIGGER update_spons_elements_for_donations AFTER INSERT ON Donations For Each Row
BEGIN
    DECLARE r_count INT;
    DECLARE r1_count INT;
    DECLARE rsp_count INT;
    DECLARE t_s_a decimal(10,2);

    DECLARE idd varchar(10);
    DECLARE amount_ decimal(10,2);
    DECLARE type_ varchar(20);

    DECLARE diff_high decimal(10,2);
    DECLARE temp_eid varchar(10);
    DECLARE temp_amount decimal(10,2);
    
    DECLARE Invalid_Spons_id CONDITION FOR SQLSTATE '02018';
    DECLARE CONTINUE HANDLER FOR Invalid_Spons_id
    RESIGNAL SET MESSAGE_TEXT = 'Invalid Spons_id. Check the spons_id correctly or insert the spons_id into the Alumni or OtherSponsors table.';

/*    
    select count(*) into r_count from Alumni where spons_id = NEW.spons_id;
    select count(*) into r1_count from OtherSponsors where spons_id = NEW.spons_id;
    select count(*) into rsp_count from SponsorshipPayment where spons_id = NEW.spons_id; */

    set r_count := count_("Alumni", NEW.spons_id);
    set r1_count := count_("OtherSponsors", NEW.spons_id);
    set rsp_count := count_("SponsorshipPayment", NEW.spons_id);

    if r_count > 0
    then
        set t_s_a := (SELECT total_spons_amount FROM Alumni where spons_id = NEW.spons_id);
        update Alumni set total_spons_amount = t_s_a + NEW.s_amount where Alumni.spons_id = NEW.spons_id;
        set amount_ := NEW.s_amount;
        WHILE amount_ > 0 do
            set diff_high := (select spons_amount - spons_amount_curr as diff from SponsorshipDetails order by diff desc limit 1);
            set temp_eid := (select event_id from (select event_id, spons_amount - spons_amount_curr as diff from SponsorshipDetails order by diff desc limit 1) as T1);
            if amount_ > diff_high
            then
                set temp_amount := amount_;
                update SponsorshipDetails set spons_amount_curr := spons_amount where event_id = temp_eid;
                set amount_ := temp_amount - diff_high;
            else 
                update SponsorshipDetails set spons_amount_curr := t_s_a + amount_ where event_id = temp_eid;
                set amount_ = 0;
            end if;
        end while;
        if rsp_count > 0
        then
            set t_s_a := (SELECT spons_amount FROM SponsorshipPayment where spons_id = NEW.spons_id);
            update SponsorshipPayment set spons_amount := t_s_a + NEW.s_amount where spons_id = NEW.spons_id;        
        else
            set idd := NEW.spons_id;
            set amount_ := NEW.s_amount;
            set type_ := "Alumni";
            INSERT INTO SponsorshipPayment(spons_id, spons_amount, spons_type) VALUES(idd, amount_, type_);
        end if;
    end if;
    if r1_count > 0
    then
        set t_s_a := (SELECT total_spons_amount FROM OtherSponsors where spons_id = NEW.spons_id);
        update OtherSponsors set total_spons_amount = t_s_a + NEW.s_amount where OtherSponsors.spons_id = NEW.spons_id;
        WHILE amount_ > 0 do
            set diff_high := (select spons_amount - spons_amount_curr as diff from SponsorshipDetails order by diff desc limit 1);
            set temp_eid := (select event_id from (select event_id, spons_amount - spons_amount_curr as diff from SponsorshipDetails order by diff desc limit 1) as T1);
            if amount_ > diff_high
            then
                set temp_amount := amount_;
                update SponsorshipDetails set spons_amount_curr := spons_amount where event_id = temp_eid;
                set amount_ := temp_amount - diff_high;
            else 
                update SponsorshipDetails set spons_amount_curr := t_s_a + amount_ where event_id = temp_eid;
                set amount_ = 0;
            end if;
        end while;
        
        if rsp_count > 0
        then
            set t_s_a := (SELECT spons_amount FROM SponsorshipPayment where spons_id = NEW.spons_id);
            update SponsorshipPayment set spons_amount := t_s_a + NEW.s_amount where spons_id = NEW.spons_id;        
        else
            set idd := NEW.spons_id;
            set amount_ := NEW.s_amount;
            set type_ := "Sponsor";
            INSERT INTO SponsorshipPayment(spons_id, spons_amount, spons_type) VALUES(idd, amount_, type_);
        end if;
    end if;
    if r_count < 1 AND r1_count < 1
    then
        SIGNAL Invalid_Spons_id;
    end if;
END//
DELIMITER ;

INSERT INTO Events VALUES ('E19_A01', 'Syngphony', 'The Solo Singing Competition where the participant along with one accompanist can perform on a song for 3-5mins. The winner will win a cash prize of Rs.10000/-.', 'Staged');
INSERT INTO Events VALUES ('E19_A02', 'Heel Turn', 'The Group Dance Competition where the participants can perform for 5-8mins. The winner will win a cash prize of Rs.14000/-.', 'Staged');
INSERT INTO Events VALUES ('E19_A03', 'Open Mic', 'The Stand-Up Comedy Event for the comedians out there. Participants can perform their gig for 5-8mins and win a cash prize of Rs.5000/-.', 'Staged');
INSERT INTO Events VALUES ('E19_A04', 'Stage Play', 'The stage play is a drama-event where teams will be given a theme 2 days prior to the competition and they can win a cash prize of Rs.10000/-.', 'Staged');
INSERT INTO Events VALUES ('E19_A05', 'Street Play', 'This is Nukkad Natak. Teams will have to perform on a given theme and they can win a cash prize of Rs.5000/-.', 'Not Staged');
INSERT INTO Events VALUES ('E19_A06', 'Verve', 'The Fashion-Walk competition for the fashion icons out there who can win a crown from the chief guest of the event.', 'Staged');
INSERT INTO Events VALUES ('E19_A07', 'Satanz Tantrum', 'The Band Competition for the bands of different colleges out there. Particiapnts will be given a stage time of 25mins and can win Rs.15000/-.', 'Staged');
INSERT INTO Events VALUES ('E19_A08', 'Darpan', 'This is the wall painting competition. A team of two can paint based on the given theme for 3 hours. Participants can win exciting prizes.', 'Not Staged');
INSERT INTO Events VALUES ('E19_A09', 'Face-Painting', 'The name speaks for itself. A team of two(one painter and the other whose face is going to be painted. Winners win exciting prizes.', 'Not Staged');
INSERT INTO Events VALUES ('E19_A10', 'Vendre', 'This is the advertising event where particiapnts should advertise a given prrroduct for 2mins and they can win a cash prize worth Rs.2500/-.', 'Not Staged');
INSERT INTO Events VALUES ('E19_A11', 'Chem-Quiz', 'This is the Chemistry Quiz. Participants can win exciting prizes.', 'Not Staged');
INSERT INTO Events VALUES ('E19_A12', 'The Hissing Serpent', 'This is a literary competition where participants shoud write in short on a given theme. They can win exciting prizes.', 'Not Staged');
INSERT INTO Events VALUES ('E19_A13', 'Rocket Propulsion', 'This is a technical event. Participants can prepare a rocket model which will be fired. Participants can win exciting prizes.', 'Not Staged');
INSERT INTO Events VALUES ('E19_C01', 'Grace Hopper Celebration - Houston', 'GHC is a series of conferences designed t bring the research and career interests of women in computing to the forefront.', 'Conference');
INSERT INTO Events VALUES ('E19_C02', 'Red Hat Summit - Boston', 'This is a yearly technology-event to showcase the latest in open source cloud computing, platform, virtualisation etc.', 'Conference');
INSERT INTO Events VALUES ('E19_C03', 'FOSSASIA - Singapore', 'A yearly technology-event to showcase the latest in open source software and hardware technologies.', 'Conference');
INSERT INTO Events VALUES ('E19_E01', 'SMC', 'The E-Club event where start-ups are made to interact with investers.', 'Entrepreneurship');

INSERT INTO SponsorshipDetails VALUES ('E19_A01',  'Prizes, Judges Remuneration', 30000.00, 0);
INSERT INTO SponsorshipDetails VALUES ('E19_A02',  'Prizes, Judges Remuneration', 40000.00, 0);
INSERT INTO SponsorshipDetails VALUES ('E19_A03',  'Prizes, Judges Remuneration', 13000.00, 0);
INSERT INTO SponsorshipDetails VALUES ('E19_A04',  'Prizes', 15000.00, 0);
INSERT INTO SponsorshipDetails VALUES ('E19_A05',  'Prizes', 10000.00, 0);
INSERT INTO SponsorshipDetails VALUES ('E19_A06',  'Crowns, Chief Guest Remuneration', 75000.00, 0);
INSERT INTO SponsorshipDetails VALUES ('E19_A07',  'Prizes, Judges Remuneration', 40000.00, 0);
INSERT INTO SponsorshipDetails VALUES ('E19_A08',  'Prizes, Paints', 7000.00, 0);
INSERT INTO SponsorshipDetails VALUES ('E19_A09',  'Prizes, Paints', 5000.00, 0);
INSERT INTO SponsorshipDetails VALUES ('E19_A10',  'Prizes', 9000.00, 0);
INSERT INTO SponsorshipDetails VALUES ('E19_A11',  'Prizes', 5000.00, 0);
INSERT INTO SponsorshipDetails VALUES ('E19_A12',  'Prizes', 5000.00, 0);
INSERT INTO SponsorshipDetails VALUES ('E19_A13',  'Prizes', 5000.00, 0);
INSERT INTO SponsorshipDetails VALUES ('E19_C01',  'Travel Grant', 80000.00, 0);
INSERT INTO SponsorshipDetails VALUES ('E19_C02',  'Travel Grant', 85000.00, 0);
INSERT INTO SponsorshipDetails VALUES ('E19_C03',  'Travel Grant', 25000.00, 0);
INSERT INTO SponsorshipDetails VALUES ('E19_E01',  'Funding Strat-Ups', 100000.00, 0);

INSERT INTO Alumni VALUES ('1401CE41', 'Srimaan', 2018, 6000.00);
INSERT INTO Alumni VALUES ('1101ME33', 'Krrish', 2015, 25000.00);
INSERT INTO Alumni VALUES ('1401CE15', 'Charan', 2018, 6000.00);
INSERT INTO Alumni VALUES ('1001ME01', 'Atul Jadhav', 2014, 14000.00);
INSERT INTO Alumni VALUES ('1301CS45', 'Rajesh', 2017, 9000.00);
INSERT INTO Alumni VALUES ('1301EE21', 'Avisradhi', 2017, 10000.00);
INSERT INTO Alumni VALUES ('1201EE55', 'Kiran', 2016, 9000.00);
INSERT INTO Alumni VALUES ('1401CE07', 'Ninja', 2018, 5000.00);
INSERT INTO Alumni VALUES ('1201CS40', 'Asutosh', 2016, 25000.00);
INSERT INTO Alumni VALUES ('0801CE49', 'Messi', 2012, 54000.00);
INSERT INTO Alumni VALUES ('1401CS11', 'Pranjali', 2018, 15000.00);
INSERT INTO Alumni VALUES ('0901ME14', 'Dubey', 2013, 45000.00);
INSERT INTO Alumni VALUES ('1401CB07', 'Gopal', 2018, 30000.00);
INSERT INTO Alumni VALUES ('1401CS33', 'Divya', 2018, 25000.00);
INSERT INTO Alumni VALUES ('1001CB23', 'Charu', 2014, 80000.00);
INSERT INTO Alumni VALUES ('1133CS56', 'Arundhati', 2015, 100000.00);
INSERT INTO Alumni VALUES ('1001CS40', 'Sathvikesh', 2014, 140000.00);
INSERT INTO Alumni VALUES ('1401CS25', 'Jolly', 2018, 138000.00);
INSERT INTO Alumni VALUES ('1112MT44', 'Karan', 2015, 10000.00);
INSERT INTO Alumni VALUES ('1332CH22', 'Poorna', 2017, 29000.00);


INSERT INTO OtherSponsors VALUES('IITP_OS001', 'Dena Bank', 'Organisation', 220000.00);
INSERT INTO OtherSponsors VALUES('IITP_OS003', 'Pizza Hut', 'Organisation', 135000.00);
INSERT INTO OtherSponsors VALUES('IITP_OS009', 'Chai Wala', 'Organisation', 90000.00);
INSERT INTO OtherSponsors VALUES('IITP_OS021', 'RedFM', 'Organisation', 100000.00);
INSERT INTO OtherSponsors VALUES('IITP_OS635', 'DanceBuzz', 'Individual', 5000.00);
INSERT INTO OtherSponsors VALUES('IITP_OS033', 'Coca Cola', 'Organisation', 365000.00);
INSERT INTO OtherSponsors VALUES('IITP_OS049', 'Tech Kings', 'Organisation', 45000.00);
INSERT INTO OtherSponsors VALUES('IITP_OS069', 'Airtel', 'Organisation', 387000.00);
INSERT INTO OtherSponsors VALUES('IITP_OS777', 'Raag', 'Individual', 10000.00);
INSERT INTO OtherSponsors VALUES('IITP_OS099', 'Amul', 'Organisation', 95000.00);
INSERT INTO OtherSponsors VALUES('IITP_OS121', 'Angeethi', 'Organisation', 75000.00);
INSERT INTO OtherSponsors VALUES('IITP_OS268', 'Sparx', 'Organisation', 31000.00);
INSERT INTO OtherSponsors VALUES('IITP_OS963', 'Krrish', 'Individual', 19000.00);
INSERT INTO OtherSponsors VALUES('IITP_OS333', 'Cinepolis', 'Organisation', 114000.00);
INSERT INTO OtherSponsors VALUES('IITP_OS868', 'Camlin', 'Organisation', 71000.00);
INSERT INTO OtherSponsors VALUES('IITP_OS969', 'PunHub', 'Individual', 34000.00);
INSERT INTO OtherSponsors VALUES('IITP_OS344', 'RaOne', 'Individual', 12000.00);

/* Displaying the spons_id of an Alumni with first name Atul */
select * from Alumni where spons_name like '%Atul%';

INSERT INTO PaymentDetails VALUES('1401CB07', 'E19_A02', 5000.00, '321654987002');
INSERT INTO PaymentDetails VALUES('IITP_OS069', 'E19_A01', 30000.00, '321654987000');
INSERT INTO PaymentDetails VALUES('IITP_OS069', 'E19_A02', 300.00, '321654997000');
select * from SponsorshipPayment;

/* Displaying the spons_id of some sponsor with first name Sparx */
select * from Alumni where spons_name like '%Sparx%';

select * from Alumni where spons_id = '1401CE41' or spons_id = 'IITP_OS069';
select * from OtherSponsors where spons_id = '1401CE41' or spons_id = 'IITP_OS069';
select * from SponsorshipDetails where event_id = 'E19_A02' or event_id = 'E19_A01';

/*Displaying the events with requirements in desc order*/
select Events.event_name from (
    select event_id, spons_amount - spons_amount_curr as diff from SponsorshipDetails order by diff desc
) as T1 inner join Events on Events.event_id = T1.event_id order by diff desc;

/* Previous Year Sponsors who have sponsored us before but haven't this Year */
select * from Alumni where spons_id not in (
    select spons_id from PaymentDetails
); 

/* Checking if a particular sponsor has sponsored us this year or not. If Null value then not */
select spons_name from SponsorshipPayment as sp inner join OtherSponsors as os on sp.spons_id = os.spons_id 
where spons_name like '%irtel%';

/* Donations have been updated */
INSERT INTO Donations(spons_id, d_reference_id, s_amount) VALUES('1401CB07', '321654987101', 1000.00);
select * from SponsorshipPayment;

INSERT INTO PaymentDetails VALUES('IITP_OS033', 'E19_A02', 35000.00, '321654987001');
INSERT INTO PaymentDetails VALUES('1401CE15', 'E19_A03', 6000.00, '321654987003');
INSERT INTO PaymentDetails VALUES('1301CS45', 'E19_A03', 4000.00, '321654987004');
INSERT INTO PaymentDetails VALUES('1201EE55', 'E19_A03', 3000.00, '321654987005');
INSERT INTO PaymentDetails VALUES('IITP_OS069', 'E19_A06', 40000.00, '321654987006');
INSERT INTO PaymentDetails VALUES('IITP_OS033', 'E19_A06', 35000.00, '321654987007');
INSERT INTO PaymentDetails VALUES('IITP_OS009', 'E19_A07', 20000.00, '321654987008');
INSERT INTO PaymentDetails VALUES('1001CB23', 'E19_A07', 20000.00, '321654987009');
INSERT INTO PaymentDetails VALUES('IITP_OS021', 'E19_C01', 30000.00, '321654987010');
INSERT INTO PaymentDetails VALUES('IITP_OS777', 'E19_C02', 10000.00, '321654987011');
INSERT INTO PaymentDetails VALUES('IITP_OS963', 'E19_C02', 9000.00, '321654987012');
INSERT INTO PaymentDetails VALUES('IITP_OS003', 'E19_C03', 25000.00, '321654987013');
INSERT INTO PaymentDetails VALUES('1001CS40', 'E19_E01', 25000.00, '321654987014');

INSERT INTO Donations VALUES('1401CB07', '321654987100', 1000.00);
INSERT INTO Donations VALUES('1112MT44', '321654987102', 4000.00);
INSERT INTO Donations VALUES('IITP_OS003', '321654987103', 10000.00);
INSERT INTO Donations VALUES('IITP_OS635', '321654987104', 5000.00);
INSERT INTO Donations VALUES('IITP_OS969', '321654987105', 8000.00);





