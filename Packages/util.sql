create or replace PACKAGE BODY util AS

--����������
    c_percent_of_min_salary CONSTANT NUMBER := 1.5;
   
   
    -- 
     FUNCTION add_year(p_date in DATE DEFAULT sysdate,
                       p_year in NUMBER ) RETURN DATE IS
    v_date DATE;
    v_year NUMBER := p_year*12 ;
    BEGIN
        SELECT add_months(p_date, v_year)
        INTO v_date
        FROM dual;
        RETURN v_date;
    END add_year;
    
    --  
    FUNCTION get_job_title ( p_employee_id IN NUMBER )  RETURN VARCHAR2 IS
        v_job_title dima.jobs.job_title%TYPE;

    BEGIN   
        SELECT jb.job_title
        INTO v_job_title
        FROM employees em
        JOIN dima.jobs jb
        ON em.job_id = jb.job_id
        WHERE em.employee_id = p_employee_id;
    
        RETURN v_job_title;
    END get_job_title;
    
    --
    FUNCTION get_dep_name(p_employee_id IN NUMBER)  RETURN VARCHAR2 IS
        v_dep_name dima.departments.department_name%type;

    BEGIN
    
        select dp.department_name
        into v_dep_name 
        from employees em
        join dima.departments dp
        on em.department_id = dp.department_id
        where em.employee_id = p_employee_id;
    
        RETURN v_dep_name;
    END get_dep_name;
    
    
    --
        FUNCTION get_sum_price_sales(p_table VARCHAR2 DEFAULT 'products') RETURN NUMBER IS
       
        v_table VARCHAR2(50) := p_table;
        v_dynamic_sql_code VARCHAR2(500);
        v_sum NUMBER;
        err_tab_ncor EXCEPTION;
        v_message dima.logs.message%TYPE;
    
    BEGIN
    
        IF v_table not in ('products_old','products') THEN
            raise err_tab_ncor;
        END IF;
    
        v_dynamic_sql_code := 'SELECT SUM(p.price_sales) FROM hr.'||v_table||' p';
    --    dbms_output.put_line(v_dynamic_sql_code);
        EXECUTE IMMEDIATE v_dynamic_sql_code INTO v_sum;
    
        RETURN v_sum;
    
    EXCEPTION
        WHEN err_tab_ncor THEN
            v_message := '"������������ ��������! ��������� products ��� products_old" (��� ������� -20001)' ||SQLERRM ;
            to_log(p_appl_proc => 'util.get_sum_price_sales', p_message => v_message);
            raise_application_error(-20001, '������������ ��������! ��������� products ��� products_old" (��� ������� -20001)');
    
    END get_sum_price_sales;
    
    --- 07 ------1
    FUNCTION table_from_list(    p_list_val IN VARCHAR2,
                                    p_separator IN VARCHAR2 DEFAULT ',') RETURN tab_value_list PIPELINED IS

    out_rec tab_value_list := tab_value_list();
    l_cur SYS_REFCURSOR;

    BEGIN
    OPEN l_cur FOR
        SELECT TRIM(REGEXP_SUBSTR(p_list_val, '[^'||p_separator||']+', 1, LEVEL)) AS cur_value
            FROM dual
        CONNECT BY LEVEL <= REGEXP_COUNT(p_list_val, p_separator) + 1;

        BEGIN
        LOOP
                EXIT WHEN l_cur%NOTFOUND;
                FETCH l_cur BULK COLLECT     
                INTO out_rec;
                FOR i IN 1 .. out_rec.count LOOP
                    PIPE ROW(out_rec(i));
                END LOOP;
        END LOOP;
    CLOSE l_cur;

        EXCEPTION

        WHEN OTHERS THEN
            IF (l_cur%ISOPEN) THEN
                    CLOSE l_cur;
                    RAISE;
            ELSE
                RAISE;
            END IF;
        END;

END table_from_list;

----7-------2
    FUNCTION get_currency (  p_currency IN VARCHAR2 DEFAULT 'USD',
                         p_exchangedate IN DATE DEFAULT SYSDATE) RETURN tab_exchange PIPELINED IS
    out_rec tab_exchange := tab_exchange();
    l_cur SYS_REFCURSOR;
    BEGIN
        OPEN l_cur FOR
        
        SELECT tt.r030, tt.txt, tt.rate, tt.cur, TO_DATE(tt.exchangedate, 'dd.mm.yyyy') AS exchangedate
        FROM (SELECT get_needed_curr(p_valcode => p_currency,p_date => p_exchangedate) AS json_value FROM dual)
            CROSS JOIN json_table
            (
            json_value, '$[*]'
            COLUMNS
                (
                r030 NUMBER PATH '$.r030',
                txt VARCHAR2(100) PATH '$.txt',
                rate NUMBER PATH '$.rate',
                cur VARCHAR2(100) PATH '$.cc',
                exchangedate VARCHAR2(100) PATH '$.exchangedate'
                )
            ) TT;
        BEGIN
        LOOP
            EXIT WHEN l_cur%NOTFOUND;
            FETCH l_cur BULK COLLECT
            INTO out_rec;
            FOR i IN 1 .. out_rec.count LOOP
                PIPE ROW(out_rec(i));
            END LOOP;
        END LOOP;
        CLOSE l_cur;
        
        EXCEPTION
        WHEN OTHERS THEN
            IF (l_cur%ISOPEN) THEN
                CLOSE l_cur;
                RAISE;
            ELSE
                RAISE;
            END IF;
        END;
    END get_currency;
    
    --h07_01--   ������� 7_01
    FUNCTION get_region_cnt_emp ( p_department_id NUMBER default null) RETURN tab_regions_list PIPELINED IS

    out_rec tab_regions_list := tab_regions_list();
    l_cur SYS_REFCURSOR;

    BEGIN
        OPEN l_cur FOR
        
            select  tt.region_name, count(tt.region_name) as emp_num
            from (  select em.employee_id, em.department_id, rg.region_id, rg.region_name
                    from hr.employees em
                    join  hr.departments dp
                        on em.department_id = dp.department_id
                    join  hr.locations lc
                        on dp.location_id = lc.location_id
                    join hr.countries cn
                        on lc.country_id = cn.country_id
                    join hr.regions rg
                        on cn.region_id = rg.region_id
            --        where em.department_id = 60
                    where em.department_id = p_department_id or p_department_id is null--em.department_id = null or null is null
                    ) tt
            group by tt.region_name;
    
            BEGIN
            LOOP
                    EXIT WHEN l_cur%NOTFOUND;
                    FETCH l_cur BULK COLLECT     
                    INTO out_rec;
                    FOR i IN 1 .. out_rec.count LOOP
                        PIPE ROW(out_rec(i));
                    END LOOP;
            END LOOP;
        CLOSE l_cur;
    
            EXCEPTION
    
            WHEN OTHERS THEN
                IF (l_cur%ISOPEN) THEN
                        CLOSE l_cur;
                        RAISE;
                ELSE
                    RAISE;
                END IF;
            END;

    END get_region_cnt_emp;

    
    --���������
    
    -- 0 --
    
    PROCEDURE check_work_time IS
                
        BEGIN
        
            IF TO_CHAR(SYSDATE, 'DY', 'NLS_DATE_LANGUAGE = AMERICAN') IN ('SAT', 'SUN') THEN
                raise_application_error (-20205, '�� ������ ������� ���� ���� � ������ ���');
            END IF;
          
                       
    END check_work_time;
    
    
    -- 1 --
        PROCEDURE add_new_jobs(   p_job_id        IN VARCHAR2,
                                  p_job_title     IN VARCHAR2,
                                  p_min_salary    IN NUMBER,
                                  p_max_salary    IN NUMBER DEFAULT NULL,
                                  po_err          OUT VARCHAR2) IS
        v_max_salary jobs.max_salary%TYPE;
        v_is_exist_job NUMBER;
        salary_err EXCEPTION;
        
    BEGIN
    
--        IF TO_CHAR(SYSDATE, 'DY', 'NLS_DATE_LANGUAGE = AMERICAN') IN ('SAT', 'SUN') THEN
--            raise_application_error (-20205, '�� ������ ������� ���� ���� � ������ ���');
--        END IF;
        check_work_time;
    
        IF p_max_salary IS NULL THEN
            v_max_salary := p_min_salary * c_percent_of_min_salary;
        ELSE
            v_max_salary := p_max_salary;
        END IF;
        
        --SELECT COUNT(j.job_id)
        --INTO v_is_exist_job
        --FROM jobs j
        --WHERE j.job_id = p_job_id;
        BEGIN
            IF ( p_min_salary < gc_min_salary OR p_max_salary < gc_min_salary ) THEN
                --po_err := '�������� �������� ����� �� 2000';
                RAISE salary_err;
            --elsif v_is_exist_job >=1 THEN
            --   po_err := '������ '||p_job_id||' ��� ����';
            ELSE
                INSERT INTO dima.jobs (job_id,job_title,min_salary,max_salary)
                VALUES (p_job_id,p_job_title,p_min_salary,v_max_salary);
                COMMIT;
                po_err := '������ '||p_job_id||' ������ ������';
            END IF;
            
        EXCEPTION
            WHEN salary_err THEN
                raise_application_error(-20001, '�������� �������� ����� �� 2000');
            WHEN dup_val_on_index THEN
                raise_application_error(-20002, '������ '||p_job_id||' ��� ����');
            WHEN OTHERS THEN
                raise_application_error(-20003, '����������� ������ ��� ���������� ���������'|| SQLERRM);
            
        END;
    END add_new_jobs;
    
    --2--
    PROCEDURE del_jobs ( p_job_id    IN VARCHAR2,
                         po_result   OUT VARCHAR2) IS
    v_job_id dima.jobs.job_id%type;                        
    BEGIN
        check_work_time;
        BEGIN
            select jb.job_id
            into v_job_id
            from dima.jobs jb
            where jb.job_id = p_job_id;
        
             delete from dima.jobs jb
             where jb.job_id = p_job_id;
             COMMIT;    
             po_result := '������ '||p_job_id||' ������ ��������';
            
        EXCEPTION
            WHEN no_data_found THEN
                raise_application_error(-20004, '"������ '|| p_job_id ||' �� ����"(��� ������� -20004)');
                        
        END;
    END del_jobs;
    
    --3--
    PROCEDURE update_balance(p_employee_id IN NUMBER,
                             p_balance IN NUMBER) IS
                             
        v_balance_new dima.balance.balance%TYPE;
        v_balance_old dima.balance.balance%TYPE;
        v_message dima.logs.message%TYPE;
    
    BEGIN
        SELECT balance
        INTO v_balance_old
        FROM dima.balance b
        WHERE b.employee_id = p_employee_id
        FOR UPDATE; -- ������� ����� ��� ���������
    
        IF v_balance_old >= p_balance THEN
            UPDATE balance b
            SET b.balance = v_balance_old - p_balance
            WHERE employee_id = p_employee_id
    
            RETURNING b.balance INTO v_balance_new; -- ��� �� ������ ����� SELECT INTO
        ELSE
            v_message := 'Employee_id = '||p_employee_id||'. ����������� ����� �� �������. �������� ������ '||v_balance_old||', ������ ������ '||p_balance||'';
            raise_application_error(-20001, v_message);
        END IF;
    
        v_message := 'Employee_id = '||p_employee_id||'. ����� ������ ���� � �������. ���� '||v_balance_old||', ����� '||v_balance_new||'';
        dbms_output.put_line(v_message);
        to_log(p_appl_proc => 'util.update_balance', p_message => v_message);
    
--        IF 1=0 THEN -- ������ ������������� �������
--            v_message := '������������� �������';
--            raise_application_error(-20001, v_message);
--        END IF;
    COMMIT; -- �������� ����� ������ �� ������� ���������� � �������� ����������
    
    EXCEPTION
        WHEN OTHERS THEN
            to_log(p_appl_proc => 'util.update_balance', p_message => NVL(v_message, 'Employee_id = '||p_employee_id||'. ' ||SQLERRM));
            ROLLBACK; -- ³������� ���������� � ��� ���������� �������
            raise_application_error(-20001, NVL(v_message, '�� ����� �������'));
    
    END update_balance;
    
    
    --4-- ��������� - ��������� ��������� ������ �����������
    
    PROCEDURE add_employee (  p_first_name IN VARCHAR2,
                              p_last_name IN VARCHAR2,
                              p_email IN VARCHAR2,
                              p_phone_number IN VARCHAR2,
                              p_hire_date IN DATE DEFAULT sysdate,
                              p_job_id IN VARCHAR2,
                              p_salary IN NUMBER,
                              p_commission_pct IN VARCHAR2,
                              p_manager_id IN NUMBER,
                              p_department_id IN NUMBER ) IS
                          
        v_job_id_exist NUMBER;
        v_department_id_exist NUMBER;
        v_sql VARCHAR2(600);
        v_min_salary NUMBER;
        v_max_salary NUMBER;
        v_employee_id NUMBER;
        v_sqlerrm VARCHAR2(600);
        
        -- ������� �������� ������� � ������� �� ������
        FUNCTION is_exist ( p_func IN VARCHAR2 DEFAULT 'count(*)',
                            p_what IN VARCHAR2,
                            p_colum IN VARCHAR2,
                            p_where IN VARCHAR2 ) RETURN NUMBER IS
                               
             v_result NUMBER;
             vv_sql VARCHAR2(600);
          BEGIN
            
            vv_sql := 'select ' || p_func ||' FROM dima.'||p_where||' p
                    WHERE p.'|| p_colum ||'='''|| p_what ||''' ';
            EXECUTE IMMEDIATE vv_sql INTO v_result;
                        
          RETURN v_result;
          END is_exist;
        --  
         FUNCTION get_max_employee_id RETURN NUMBER IS
             vv_employee_id NUMBER;
          BEGIN
            SELECT NVL(MAX(employee_id),0)+1
            INTO vv_employee_id
            FROM dima.employees;
          RETURN vv_employee_id;
          END get_max_employee_id;
          
        --
                          
    BEGIN
        --1
            log_util.log_start('add_employee');
            
        --2 �������� 1
            v_job_id_exist := is_exist('count(*)',p_job_id,'job_id','jobs');
            
                IF v_job_id_exist =0 THEN
                    raise_application_error(-20001,'������� ��������� ��� ������');
                END IF;
                
        --3 �������� 2  
            v_department_id_exist := is_exist ('count(*)',p_department_id,'department_id','departments');
                
                IF v_department_id_exist =0 THEN
                    raise_application_error(-20001,'������� ��������� ������������� �����');
                END IF;
        
        --4 �������� 3    
             v_min_salary := is_exist('min_salary',p_job_id,'job_id','jobs');
             v_max_salary := is_exist('max_salary',p_job_id,'job_id','jobs');
                
                 IF p_salary < v_min_salary or p_salary > v_max_salary  THEN
                    raise_application_error(-20001,'������� ������������ �������� ����� ��� ������ ���� ������');
                 END IF;
        
        --5 �������� �������� �������
                IF TO_CHAR(SYSDATE, 'DY') IN ('��', '��') OR TO_CHAR(SYSDATE, 'hh24') < 8 OR TO_CHAR(SYSDATE, 'hh24') > 17 THEN
                        raise_application_error (-20001, '�� ������ �������� ������ ����������� ���� � ������� ���');
                    END IF;
                    
        --6
            v_employee_id := get_max_employee_id();
        
        INSERT INTO dima.employees(employee_id, first_name, last_name, email, phone_number, hire_date, job_id, salary, commission_pct, manager_id, department_id)
        VALUES(v_employee_id, p_first_name, p_last_name, p_email, p_phone_number, p_hire_date, p_job_id, p_salary, p_commission_pct, p_manager_id, p_department_id);
        COMMIT;
        
--        ���������� ��'�, �������, ��� ������, �� ������������ ������ ������ �� �������
        dbms_output.put_line('���������� '||p_first_name||' '||p_last_name ||' ' ||p_job_id ||' �� ������������='||p_department_id|| '������ ������ �� �������');
        
        log_util.log_finish('add_employee','gg');

        
    EXCEPTION
        
        WHEN OTHERS THEN
            v_sqlerrm := sqlerrm ||' �� ����� �������' ;
            log_util.log_error('add_employee',  v_sqlerrm); 
            ROLLBACK; -- ³������� ���������� � ��� ���������� �������
            raise_application_error(-20001, sqlerrm);
    
    END add_employee;

        --

    
END util;