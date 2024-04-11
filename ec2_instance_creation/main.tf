provider "aws" {
        region = "us-east-1"
}

resource "aws_instance" "example" {
        ami = "ami-08116b9957a259459"
        instance_type = "t2.micro"
}