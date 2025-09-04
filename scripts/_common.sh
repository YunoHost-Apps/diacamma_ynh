#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

APPLITYPE="lucterios.standard"
MODULES="lucterios.contacts,lucterios.documents,lucterios.mailing"
DATABASE="postgresql:name=$db_name,user=$db_user,password=$db_pwd,host=localhost"
if [ "$lct_appli" == "asso" ]
then
    MODULES+=",diacamma.accounting,diacamma.payoff,diacamma.invoice,diacamma.member,diacamma.event"
    APPLITYPE="diacamma.asso"
fi
if [ "$lct_appli" == "syndic" ]
then
    MODULES+=",diacamma.accounting,diacamma.payoff,diacamma.condominium"
    APPLITYPE="diacamma.syndic"
fi

#=================================================
# PERSONAL HELPERS
#=================================================

function install_in_venv()
{
    pushd $install_dir
    ynh_safe_rm venv
    python3 -m venv venv
    if [ $develop -eq 1 ]
    then
        ynh_config_add --template="extra_url" --destination="./extra_url"
        pip_option='--extra-index-url https://pypi.diacamma.org/simple'
    else
        pip_option=''
    fi
    venv/bin/pip3 install -U lucterios lucterios-standard lucterios-contacts lucterios-documents $pip_option 
    venv/bin/pip3 install -U diacamma-asso diacamma-syndic diacamma-financial $pip_option
    venv/bin/pip3 install -U gunicorn psycopg2-binary psycopg2 django-auth-ldap3-ad
    sed -i 's|member=%s|inheritPermission=%s|g' venv/lib/python*/site-packages/django_auth_ldap3_ad/auth.py
    venv/bin/lucterios_admin.py installed
    chown -R ${app}:www-data "$install_dir/venv"
    chmod -R ogu+rw "$install_dir/venv"
    chmod ogu+x "$install_dir/venv"
    chmod ogu+x "$install_dir/venv/bin"
    chmod ogu+x "$install_dir/venv/bin/gunicorn"
    popd
}

function refresh_collect()
{
    pushd $install_dir
    venv/bin/python3 manage_inst-${app}.py collectstatic --noinput -l
    ynh_safe_rm inst-${app}/static/static
    ynh_safe_rm inst-${app}/static/tmp
    ynh_safe_rm inst-${app}/static/usr
    ynh_safe_rm inst-${app}/static/__pycache__
    ynh_safe_rm inst-${app}/static/settings.py
    ynh_safe_rm inst-${app}/static/__init__.py
    chown -R ${app}:www-data .
    chmod -R ogu+rw "$install_dir/inst-${app}"
    chmod ogu+x "$install_dir/inst-${app}"
    chmod 750 .
    popd
}

function check_params()
{
    pushd $install_dir
    ynh_config_add --template="diacamma_script.py" --destination="/tmp/diacamma_script.py"
    venv/bin/python3 manage_inst-${app}.py shell < /tmp/diacamma_script.py
    venv/bin/lucterios_admin.py security -n inst-${app} -e "MODE=0"
    popd
}


function update_software()
{
    pushd $install_dir
    venv/bin/lucterios_admin.py check
    venv/bin/lucterios_admin.py update
    venv/bin/lucterios_admin.py refreshall
    popd
}