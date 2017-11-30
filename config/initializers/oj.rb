require 'oj'

Oj.optimize_rails()

# This is just the classes the above is supposed to do by default (plus our Page
# and Version models), but explicitly specifying it does make a difference.
Oj::Rails.optimize(
  Array,
  BigDecimal,
  Float,
  Hash,
  Range,
  Regexp,
  Time,
  ActiveSupport::TimeWithZone,
  ActionController::Parameters,
  Page,
  Version
)
