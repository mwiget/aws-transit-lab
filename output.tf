output "benchr1_public_ip" {
  value = aws_instance.benchr1.public_ip
}
output "benchr2_public_ip" {
  value = aws_instance.benchr2.public_ip
}
output "benchr1_public_ipv6" {
  value = aws_instance.benchr1.ipv6_addresses
}
output "benchr2_public_ipv6" {
  value = aws_instance.benchr2.ipv6_addresses
}
