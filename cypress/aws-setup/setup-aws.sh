export REGION=us-east-1
echo "Region is: $REGION"

echo "Creating VPC..."
export VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region $REGION | jq -r ".Vpc.VpcId")
aws ec2 wait vpc-available --vpc-ids $VPC_ID
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames "{\"Value\":true}" --region $REGION
echo "VPC created: $VPC_ID"

echo "Creating Internet Gateway..."
export IGW_ID=$(aws ec2 create-internet-gateway --region $REGION | jq -r ".InternetGateway.InternetGatewayId")
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION
echo "Internet Gateway created: $IGW_ID"

echo "Creating Public Subnet..."
export PUB_SN_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.0.0/20 --availability-zone $(echo $REGION)a --region $REGION | jq -r ".Subnet.SubnetId")
aws ec2 wait subnet-available --subnet-ids $PUB_SN_ID
aws ec2 modify-subnet-attribute --subnet-id $PUB_SN_ID --map-public-ip-on-launch --region $REGION
echo "Public Subnet created: $PUB_SN_ID"

echo "Creating Private Subnet..."
export PRV_SN_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.16.0/20 --availability-zone $(echo $REGION)a --region $REGION | jq -r ".Subnet.SubnetId")
aws ec2 wait subnet-available --subnet-ids $PRV_SN_ID
echo "Private Subnet created: $PRV_SN_ID"

echo "Creating Ellastic IP..."
export EIP_ID=$(aws ec2 allocate-address --domain vpc --region $REGION | jq -r ".AllocationId")
echo "Ellastic IP created: $EIP_ID"

echo "Creating NAT Gateway..."
export NGW_ID=$(aws ec2 create-nat-gateway --subnet-id $PUB_SN_ID --allocation-id $EIP_ID --region $REGION | jq -r ".NatGateway.NatGatewayId")
aws ec2 wait nat-gateway-available --nat-gateway-ids $NGW_ID
echo "NAT Gateway created: $NGW_ID"

echo "Creating Public Route Table..."
export PUB_RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION | jq -r ".RouteTable.RouteTableId")
aws ec2 create-route --route-table-id $PUB_RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION
aws ec2 associate-route-table --route-table-id $PUB_RT_ID --subnet-id $PUB_SN_ID --region $REGION
echo "Public Route Table created: $PUB_RT_ID"

echo "Creating Private Route Table..."
export PRV_RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION | jq -r ".RouteTable.RouteTableId")
aws ec2 create-route --route-table-id $PRV_RT_ID --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NGW_ID --region $REGION
aws ec2 associate-route-table --route-table-id $PRV_RT_ID --subnet-id $PRV_SN_ID --region $REGION
echo "Private Route Table created: $PRV_RT_ID"

echo "Creating Security Group..."
export SG_ID=$(aws ec2 create-security-group --group-name "CodeBuild" --description "Security group CodeBuild" --vpc-id $VPC_ID | jq -r ".GroupId")
aws ec2 wait security-group-exists --group-ids $SG_ID
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol "tcp" --port "22" --cidr "0.0.0.0/0"
echo "Security Group created: $SG_ID"

echo "Creating Role..."
export ROLE_ARN=$(aws iam create-role --role-name CodeBuildServiceRole --assume-role-policy-document file://codebuild-create-policy.json | jq -r ".Role.Arn")
aws iam wait role-exists --role-name CodeBuildServiceRole
aws iam put-role-policy --role-name CodeBuildServiceRole --policy-name CodeBuildServiceRolePolicy --policy-document file://codebuild-put-policy.json
echo "Role created: $ROLE_ARN"

echo "Importing Github Token..."
export TOKEN_ARN=$(aws codebuild import-source-credentials --cli-input-json file://codebuild-github-access.json | jq -r ".arn")
echo "Github Token imported: $TOKEN_ARN"

echo "Tagging resources..."
aws ec2 create-tags --resources $VPC_ID \
$IGW_ID \
$PUB_SN_ID \
$PRV_SN_ID \
$EIP_ID \
$NGW_ID \
$PUB_RT_ID \
$PRV_RT_ID \
$SG_ID \
--tags Key=Name,Value=CodeBuild
echo "Resources tagged! (Key=Name,Value=CodeBuild)"

aws s3api create-bucket --bucket $(jq -r .name ../../package.json)-test-results

aws codebuild create-project --name $(jq -r .name ../../package.json)-test \
--source file://codebuild-project-source.json \
--source-version "test" \
--artifacts "type=NO_ARTIFACTS" \
--environment file://codebuild-project-environment.json \
--service-role $ROLE_ARN \
--vpc-config vpcId=$VPC_ID,subnets=$PUB_SN_ID,$PRV_SN_ID,securityGroupIds=$SG_ID
