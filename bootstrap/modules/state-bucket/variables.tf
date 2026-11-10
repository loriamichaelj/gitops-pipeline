variable "project_id" {
  type = string
}

variable "name" {
  description = "Globally unique bucket name."
  type        = string
}

variable "location" {
  type    = string
  default = "us-central1"
}

variable "keep_versions" {
  description = "Noncurrent state versions kept per object."
  type        = number
  default     = 30
}

variable "labels" {
  type    = map(string)
  default = {}
}
