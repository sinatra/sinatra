module Kernel
  # (Taken from ActiveSupport)
  # Sets $VERBOSE to nil for the duration of the block and back to its original value afterwards.
  #
  #   silence_warnings do
  #     value = noisy_call # no warning voiced
  #   end
  #
  #   noisy_call # warning voiced
  def silence_warnings
    old_verbose, $VERBOSE = $VERBOSE, nil
    yield
  ensure
    $VERBOSE = old_verbose
  end
end
