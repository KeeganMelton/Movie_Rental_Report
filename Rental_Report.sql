/*
A CREATE TABLE AS statement is written to hold a generated detailed report to show how many rentals each customer made. 
It consolidates the user’s first and last name from the customer table into one column. 
Then all rentals for each individual customer are totaled. 
Each customer is given a status in the rewards program based on the number of rentals, 
and the remaining rentals for each customer to the next reward status are displayed. 
*/

Create table rewards_details as
select 
concat_ws(' ', first_name, last_name) as "Customer Name",  
count(rental.inventory_id) AS "Movies Rented", 
case     
   when count(rental.inventory_id) < 10 then 'Upcomer' 
   when count(rental.inventory_id) >= 10 and count(rental.inventory_id) <= 24 then 'Rental Rockstar' 
   when count(rental.inventory_id) >= 25 then 'Movie Marathoner' 
   else 'N/A' end   
   as "Rewards Program Status" , 
to_next_status(count(rental.inventory_id)) as "Rentals to Next Status"
from customer  
join rental  
   on rental.customer_id = customer.customer_id  
group by "Customer Name" 
order by "Customer Name";

/*
A rewards_summary table is created using a CREATE TABLE AS statement. 
The results from the rewards_details table are totaled and grouped by rewards status. 
*/

Create table rewards_summary as 
select "Rewards Program Status",
count ('Rewards Program Status') as "Customers at this rewards level"
from rewards_details
group by "Rewards Program Status";

/*
Trigger functions and triggers are created to keep the reports up to date as new information is inserted into the tables.
Since the rewards_details table is populated from the customer and rental tables the trigger function will be set to run if 
an insert in made on either the customer or the rental tables. Additionally, the rewards_summary table will require one as 
the rewards_details table contents are used to populate its contents.
*/

create or replace function customer_total_rentals () 
returns trigger 
language plpgsql 
as $$ 
begin 
delete from rewards_details; 
insert into rewards_details 
select   
concat_ws(' ', first_name, last_name) as "Customer Name",    
count(rental.inventory_id) AS "Movies Rented",   
case       
when count(rental.inventory_id) < 10 then 'Upcomer'
when count(rental.inventory_id) >= 10 and count(rental.inventory_id) <= 24 then
'Rental Rockstar'   
when count(rental.inventory_id) >= 25 then 'Movie Marathoner'   
else 'N/A' end     
as "Rewards Program Status",
to_next_status(count(rental.inventory_id)) as “Rentals to Next Status”
from customer
join rental    
on rental.customer_id = customer.customer_id
group by "Customer Name"   
order by "Customer Name"; 
return new; 
end;
$$;

-- Creates trigger to run on an insert to the customer table 

create trigger refresh_rental_count_customer 
after insert
on customer 
for each statement 
execute procedure customer_total_rentals();

-- Creates trigger function to delete and replace data in the rewards_summary table   

create or replace function rewards_status_total()  
returns trigger  
language plpgsql  
as $$  
begin  
delete from rewards_summary;  
insert into rewards_summary  
select "Rewards Program Status",  
count ('Rewards Program Status') as "Customers at this rewards level"  
from rewards_details  
group by "Rewards Program Status";      
return new;  
end; 
$$; 

-- Creates trigger to run on an insert to the rewards_details table 
  
Create trigger refresh_rewards_summary 
after insert 
on rewards_details 
for each statement 
execute procedure rewards_status_total();
