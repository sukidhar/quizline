# $1 = name of constraint
# $2 = label to be constrained
# $3 = field of the label
create_required_constraint(){
    until cypher-shell -u "neo4j" -p "letmein" "CREATE CONSTRAINT $1 IF NOT EXISTS FOR (n:$2) REQUIRE n.$3 IS NOT NULL";
    do
        echo "failed to create index"
	    sleep 2s
    done
    echo "created required constraint : $1 on label $2 for field $3"
}

# $1 = name of constraint
# $2 = label to be constrained
# $3 = field of the label
create_unique_constraint(){
    until cypher-shell -u "neo4j" -p "letmein" "CREATE CONSTRAINT $1 IF NOT EXISTS FOR (n:$2) REQUIRE n.$3 IS UNIQUE";
    do
        echo "failed to create index"
	    sleep 2s
    done
    echo "created unique constraint : $1 on label $2 for field $3"
}

drop_schema(){
    until cypher-shell -u "neo4j" -p "letmein" "CALL apoc.schema.assert({}, {})";
     do
        echo "failed to create index"
	    sleep 2s
    done
    echo "dropped schema"
}

create_index(){
    until cypher-shell -u "neo4j" -p "letmein" "CREATE INDEX $1 IF NOT EXISTS FOR (t:$2) ON (t.$3)"
    do
        echo "failed to create index"
	    sleep 2s
    done
    echo "created index : $1 on label $2 for field $3"
}

drop_schema
create_unique_constraint "unique_admin_id" "Admin" "id"
create_unique_constraint "unique_admin_email" "Admin" "email"
create_required_constraint "mandatory_admin_id" "Admin" "id"
create_required_constraint "mandatory_admin_email" "Admin" "email"

create_unique_constraint "unique_user_id" "User" "id"
create_unique_constraint "unique_user_email" "User" "email"
create_required_constraint "mandatory_user_id" "User" "id"
create_required_constraint "mandatory_user_email" "User" "email"

create_unique_constraint "unique_student_id" "Student" "id"
create_unique_constraint "unique_student_email" "Student" "email"
create_required_constraint "mandatory_student_id" "Student" "id"
create_required_constraint "mandatory_student_email" "Student" "email"

create_unique_constraint "unique_invigilator_id" "Invigilator" "id"
create_unique_constraint "unique_invigilator_email" "Invigilator" "email"
create_required_constraint "mandatory_invigilator_id" "Invigilator" "id"
create_required_constraint "mandatory_invigilator_email" "Invigilator" "email"

create_unique_constraint "unique_department_email" "Department" "email"
create_required_constraint "mandatory_department_email" "Department" "email"
create_unique_constraint "unique_branch_id" "Branch" "id"
create_required_constraint "mandatory_branch_id" "Branch" "id"
create_unique_constraint "unique_semester_id" "Semester" "sid"
create_required_constraint "mandatory_semester_id" "Semester" "sid"

create_unique_constraint "unique_subject_code" "Subject" "subject_code"
create_required_constraint "mandatory_subject_code" "Subject" "subject_code"