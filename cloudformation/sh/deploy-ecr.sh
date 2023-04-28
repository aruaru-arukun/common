### DockerイメージをECRにデプロイするスクリプト ###
# ヘルプ
function usage {
    cat <<EOM
Usage: $(basename "$0") [OPTION]...
    -h          ヘルプ
    -i version  [必須]ECRのイメージタグ
    -e stg     [必須]デプロイする環境を指定するオプション。pro|stgに対応しており、その他はエラーを出力する。
    -p profile  [必須]AWS CLIのプロファイルを指定するオプション。
EOM
    exit 2
}

# オプション変数の初期値
ENV=""
PROFILE=""
IMAGE_VERSION=""

# オプション解析
while getopts i:e:p:h:s OPT; do
    case $OPT in
    i)
        IMAGE_VERSION=${OPTARG}
        ;;
    e)
        if [ ${OPTARG} = "pro" ] || [ ${OPTARG} = "stg" ] || [ ${OPTARG} = "dev" ];
        then
            ENV=${OPTARG}
        else
            echo "error->Env not supported->${OPTARG}"
            exit 1
        fi
        ;;
    p)
        PROFILE=${OPTARG}
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

if [ "${IMAGE_VERSION}" = "" ];
then
    echo "error->This value is required->-i"
    usage && exit 1
fi

if [ "${ENV}" = "" ];
then
    echo "error->This value is required->-e"
    usage && exit 1
fi

# 環境変数をインポート
. ./cloudformation/config/parameters.txt

# ECR名を作成
APP_ECR_NAME="${SERVICE_NAME}-ecr-${ENV}"
APP_DOCKER_PATH="./docker/app/Dockerfile"

# dockerクライアント情報を取得
ACCOUNT_ID=$(aws sts --profile ${PROFILE} get-caller-identity | jq -r '.Account')
REGION=$(aws configure get region --profile ${PROFILE})

aws ecr get-login-password --profile ${PROFILE} --region ${REGION} | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# ビルド
if ! docker buildx build . -t ${APP_ECR_NAME} --force-rm=true -f ${APP_DOCKER_PATH} --build-arg APP_ENV=${APP_ENV} --load ${APP_CACHE};
then
    echo "build error->${APP_ECR_NAME}" >&2
    exit 1
fi

# ECRにPush
docker tag ${APP_ECR_NAME}:latest ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${APP_ECR_NAME}:${IMAGE_VERSION}
if ! docker push ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${APP_ECR_NAME}:${IMAGE_VERSION};
then
    echo "push error->${APP_ECR_NAME}" >&2
    exit 1
fi