
----- 1 ----------------
begin
log_util.log_start('add_user');


end;
/
------ 2 ------------------
begin
    util.add_employee (  p_first_name => 'AAAA',
                         p_last_name => 'BBB',
                         p_email => 'eeeeee',
                         p_phone_number => '2345556789',
--                         p_hire_date => '04.07.2023',--to_date('04.07.2023','dd.mm.yyyy'),
                         p_job_id => 'SA_MAN',
                         p_salary => 10000,
                         p_commission_pct => '0,25',
                         p_manager_id => 120,
                         p_department_id => 30 );
end;
/

---- 3 ------------------------
begin
    util.fire_an_employee (513);
end;
/

---- 4 ------------------------
begin
        util.change_attribute_employee ( p_employee_id => '512',
                                        p_last_name => 'hhhh',
                                        p_email => 'ddd',
                                        p_job_id => 'SSSSSS',
                                        p_salary => 15666,
                                        p_manager_id => 555
                                        );

end;
/

------ 5 --------------------------
DECLARE
vv VARCHAR2(5000);
BEGIN
    util.copy_table (   p_source_scheme =>'HR',
                        p_target_scheme =>'DIMA',
                        p_list_table =>'EMPLOYEES,LOGS,COUNTRIES,JOBS,LOCATIO,LOCATIONS',
                        p_copy_data => TRUE,
                        po_result => vv ) ;

    dbms_output.put_line(vv);
END;
/

---------- 6 ---------------------------


BEGIN
        util.api_nbu_sync();
--        util.api_nbu_sync('USD');
end;
/
