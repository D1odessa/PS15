--4-- �������� ��������� ������ �����������
          
            --UTIL
            
    PROCEDURE add_employee (  p_first_name IN VARCHAR2,
                              p_last_name IN VARCHAR2,
                              p_email IN VARCHAR2,
                              p_phone_number IN VARCHAR2,
                              p_hire_date IN DATE DEFAULT sysdate,
                              p_job_id IN VARCHAR2,
                              p_salary IN NUMBER,
                              p_commission_pct IN VARCHAR2,
                              p_manager_id IN NUMBER,
                              p_department_id IN NUMBER );

            --UTIL Body
    
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