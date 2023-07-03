CREATE PACKAGE log_util AS

        --������� --

  
        --��������� ---
    PROCEDURE log_start ( p_proc_name IN VARCHAR2,
                          p_text IN VARCHAR2 DEFAULT NULL );
                          
    PROCEDURE log_finish ( p_proc_name IN VARCHAR2,
                           p_text IN VARCHAR2 DEFAULT NULL );
                           
    PROCEDURE log_error ( p_proc_name IN VARCHAR2,
                          p_sqlerrm IN VARCHAR2,
                          p_text IN VARCHAR2 DEFAULT NULL );
  
END log_util;
/

------
CREATE PACKAGE BODY log_util AS


  
        --��������� ---
    --
    PROCEDURE log_start ( p_proc_name IN VARCHAR2,
                          p_text IN VARCHAR2 DEFAULT NULL ) IS
        v_text VARCHAR2(120);
    
    BEGIN
    
        IF p_text IS NULL THEN
            v_text := '����� ���������, ����� ������� = '|| p_proc_name;
        ELSE
            v_text := p_text;
        END IF;
        
        to_log(p_appl_proc => p_proc_name, p_message => v_text);
        
    END log_start;
    
    --                      
    PROCEDURE log_finish ( p_proc_name IN VARCHAR2,
                           p_text IN VARCHAR2 DEFAULT NULL )IS
        v_text VARCHAR2(120);
    
    BEGIN
    
        IF p_text IS NULL THEN
            v_text := '���������� ���������, ����� ������� = '|| p_proc_name;
        ELSE
            v_text := p_text;
        END IF;
        
        to_log(p_appl_proc => p_proc_name, p_message => v_text);
    
    END log_finish;
    
    --                       
    PROCEDURE log_error ( p_proc_name IN VARCHAR2,
                          p_sqlerrm IN VARCHAR2,
                          p_text IN VARCHAR2 DEFAULT NULL ) IS
        v_text VARCHAR2(120);
    
    BEGIN
    
        IF p_text IS NULL THEN
            v_text := '� �������� '|| p_proc_name || ' ������� �������. ' || p_sqlerrm;
        ELSE
            v_text := p_text;
        END IF;
        
        to_log(p_appl_proc => p_proc_name, p_message => v_text);
                          
    END log_error;
  
END log_util;
/
-----
begin
log_util.log_start('add_user');
end;
/