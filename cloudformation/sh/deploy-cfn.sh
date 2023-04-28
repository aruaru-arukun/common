### CloudFormationをデプロイするスクリプト ###

# ヘルプ
function usage {
    cat <<EOM
Usage: $(basename "$0") [OPTION]...
    -h          ヘルプ
    -c app      [必須]デプロイするCfnを指定するオプション。app|sec|monに対応しており、その他はエラーを出力する。
    -e stg     [必須]デプロイする環境を指定するオプション。pro|stgに対応しており、その他はエラーを出力する。
    -p profile  [必須]AWS CLIのプロファイルを指定するオプション。
    -i version  [-cにecsを指定した場合必須]ECRのイメージタグ
EOM
    exit 2
}

# オプション変数の初期値
CFN=""
ENV=""
PROFILE=""
IMAGE_VERSION=""

# オプション解析
while getopts c:e:p:i:h OPT; do
    case $OPT in
    c)
        CFN=${OPTARG}
        ;;
    e)
        if [ ${OPTARG} = "pro" ] || [ ${OPTARG} = "stg" ];
        then
            ENV=${OPTARG}
        else
            echo "error->env not supported->${OPTARG}"
            exit 1
        fi
        ;;
    p)
        PROFILE=${OPTARG}
        ;;
    i)
        IMAGE_VERSION=${OPTARG}
        ;;
    h | \?)
        usage && exit 1
        ;;
    esac
done

# バリデーション
if [ "${PROFILE}" = "" ];
then
    echo "error->This value is required->-p"
    usage && exit 1
fi

if [ "${CFN}" = "" ];
then
    echo "error->This value is required->-c"
    usage && exit 1
fi

if [ "${ENV}" = "" ];
then
    echo "error->This value is required->-e"
    usage && exit 1
fi

# 環境変数をインポート
. ./cloudformation/config/parameters.txt

# デプロイするCfnファイルとスタック名を設定
TEMPLATE_PATH=""
STACK_NAME=""

# Application.yml
if [ "${CFN}" = "app" ];
then
    TEMPLATE_PATH='./cloudformation/Application.yml'
    STACK_NAME="${PRODUCT_NAME}-${SERVICE_NAME}-application-${ENV}"

# Securiy.yml
elif [ "${CFN}" = "sec" ];
then
    TEMPLATE_PATH='./cloudformation/Security.yml'
    STACK_NAME="${PRODUCT_NAME}-${SERVICE_NAME}-security-${ENV}"

# ECR.yml
elif [ "${CFN}" = "ecr" ];
then
    TEMPLATE_PATH='./cloudformation/ECR.yml'
    STACK_NAME="${PRODUCT_NAME}-${SERVICE_NAME}-ecr-${ENV}"

# Monitoring.yml
elif [ "${CFN}" = "mon" ];
then
    TEMPLATE_PATH='./cloudformation/Monitoring.yml'
    STACK_NAME="${PRODUCT_NAME}-${SERVICE_NAME}-monitoring-${ENV}"

else
    echo "error->cfn not supported->${CFN}"
    exit 1
fi

# デプロイ
OUTPUT=""
OUTPUT=$(rain deploy ${TEMPLATE_PATH} ${STACK_NAME} -y -p ${PROFILE} --params Env=${ENV},ServiceName=${SERVICE_NAME} 2>&1)
RESULT=$?

# CloudFormationに変更がなかった場合もエラーになるため、エラーメッセージで判定して回避
if [ "${OUTPUT}" == "error creating changeset: No updates are to be performed." ] || [ "$OUTPUT" == "error creating changeset: The submitted information didn't contain changes. Submit different information to create a change set." ];
then
    echo "No updates are to be performed."
    exit 0
else
    echo "${OUTPUT}"
    exit $RESULT
fi