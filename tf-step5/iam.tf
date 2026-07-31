##################################################
# EC2에 SSM 을 사용할 수 있도록 IAM Role 정의 적용
# 퍼블릭/프라이빗 접근 가능 -> 주로 프라이빗
##################################################

# EC2가 IAM 역할을 맡을 수 있도록 정책 조회
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "ec2_ssm" {
  name               = "${local.project}-EC2-SSM-Role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${local.project}-EC2-SSM-Profile"
  role = aws_iam_role.ec2_ssm.name
}