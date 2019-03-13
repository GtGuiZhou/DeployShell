# 这个shell可以实现自动创建中转仓库和部署仓库
# 1.创建中间仓库 
#   让本地能够将代码上传到本仓库 
#   本地上传代码后能够触发hooks中的post-receive脚本，实现部署仓库的代码clone
# 2.创建部署仓库 将中间仓库的代码clone保存
# 3.创建post-receive脚本，实现部署仓库的代码clone
# 4.post-receive脚本，clone代码，检测项目中是否存在deploy.sh文件，如果存在则执行该脚本
#

# 该环境变量会影响部分git命令的执行
unset GIT_DIR
 # 建立仓库和生产仓库时，将他们的权限更改为该用户和分组
user="www" 
group="www"
origin="origin" # 部署的生产仓库使用的origin
branch="master" # 部署的生产仓库使用的分支
project_name="${project_path##*/}"
middle_store_root_path=$(dirname $(pwd)) # 裸仓库根目录
cur_work_path="${middle_store_root_path}/${project_name}" # TODO 将hooks脚本分离出去适合用到
produce_store_root_path="/www/wwwroot" # 生产仓库根目录

# 接受参数
while getopts ":o:b:" opt
do
        case $opt in
            o)
            origin=$OPTARG;;
            b)
            branch=$OPTARG;;
        esac
done

# 输入项目名称
while :
do
    # 输入项目名称
    read -p "请输入项目名称,会自动添加.git结尾,输入exit可以退出：" item_name
    if [ "${item_name}"x == "exit"x ]
    then
        exit 0
    fi
    # 检测裸仓库
    cd $middle_store_root_path
    if [ -d "${item_name}.git" ]
    then
        read -p "该项目裸仓库已经存在，是否删除原有文件夹在进行创建？y/n：" input
        if [ "${input}"x == "y"x ]
        then
            rm -rf "${item_name}.git"
        else
            continue
        fi
    fi
    # 检测生产仓库
    cd $produce_store_root_path
    if [ -d $item_name ]
    then
        read -p "该项目生产仓库已经存在，是否删除原有文件夹在进行创建？y/n：" input 
        if [ "${input}"x == "y"x ]
        then
            rm -rf $item_name
            break
        else
            continue
        fi
    else
        break    
    fi
done


echo "创建裸仓库中..."
cd $middle_store_root_path
git init --bare "${item_name}.git"
chown $user:$group -R "${item_name}.git" # 修改裸仓库的所属用户

echo "克隆生产仓库..."
cd $produce_store_root_path
git clone "${middle_store_root_path}/${item_name}.git" 
chown $user:$group -R $item_name # 修改生产仓库的所属用户

echo "写入自动化部署钩子内容"
produce_store_path="${produce_store_root_path}/${item_name}"
hooks_path="${middle_store_root_path}/${item_name}.git/hooks/post-receive" 
cat > $hooks_path <<EOF
 # 该环境变量会影响部分git命令的执行
 unset GIT_DIR
 cd $produce_store_path
 git pull $origin $branch
 # 执行部署脚本
 deploy_shell_path="${produce_store_path}/deploy.sh"
 if [ -d $deploy_shell_path ]
 then
    if [ -x $deploy_shell_path ]
    then
        ${produce_store_path}/deploy.sh
    else
        echo '无法执行deploy.sh，因为该文件没有可执行权限'
    fi
 fi
 echo '生产仓库更新完毕'
EOF
echo "创建钩子于 ${hooks_path}"
chown $user:$group $hooks_path # 修改钩子的所属用户
chmod u+x $hooks_path # 让钩子可以被执行

echo "自动化部署仓库创建完毕"
exit 0
