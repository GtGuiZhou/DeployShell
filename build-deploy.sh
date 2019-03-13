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
 # 建立仓库和生产环境时，将他们的权限更改为该用户和分组
user="www" 
group="www"
origin="origin" # 部署的生产环境使用的origin
branch="master" # 部署的生产环境使用的分支
middle_store_root_path=$(dirname $(pwd)) # 裸仓库根目录
produce_store_root_path="/www/wwwroot" # 生产环境根目录

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
item_path=""
while :
do
read -p "请输入项目名称,会自动添加.git结尾,输入exit可以退出：" item_name
if [ "${item_name}"x == "exit"x ]
then
	exit 0
fi
item_path="/www/${middle_store_path}/${item_name}.git"
if [ -d $item_path ]
 then
	echo "该项目已经存在"
 else
	break
fi
done

# 生产环境目录
produce_store_path="${produce_store_root_path}/${item_name}"

echo "创建裸仓库中..."
cd $middle_store_root_path
git init --bare "${item_name}.git"
chown $user:$group -R $item_path # 修改裸仓库的所属用户
hooks_dir_path="${middle_store_root_path}/${item_name}.git"

echo "克隆生产仓库..."
middle_store_path="${middle_store_root_path}/${item_name}.git"
cd $produce_store_root_path
git clone $middle_store_path 
chown $user:$group -R $produce_store_path # 修改生产环境的所属用户


hooks_path="${hooks_dir_path}/post-receive"
echo "创建钩子于 ${hooks_path}"
touch $hooks_path

chown $user:$group $hooks_path # 修改钩子的所属用户
chmod u+x $hooks_path # 让钩子可以被执行

echo "写入自动化部署hook内容"
cat > $hooks_path <<EOF
 # 该环境变量会影响部分git命令的执行
 unset GIT_DIR
 cd $produce_store_path
 git fetch $origin $branch
 # 执行部署脚本
 deploy_shell_path="${produce_store_path}/deploy.sh"
 if [ -d $deploy_shell_path ]
 then
    if [ -x $deploy_shell_path ]
    then
        echo $deploy_shell_path
    else
        echo '无法执行deploy.sh，因为该文件没有可执行权限'
    fi
 fi
EOF

echo "自动化部署仓库创建完毕"
exit 0
