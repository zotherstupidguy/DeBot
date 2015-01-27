class Errno < Exception
  EINTR = 4

  getter errno

  def initialize(message)
    errno = C.errno
    @errno = errno
    super "#{message}: #{String.new(C.strerror(errno))}"
  end
end

module IO
  def self.select(readfds : Array(FileDescriptorIO)?, writefds = nil : Array(FileDescriptorIO)?, errorfds = nil : Array(FileDescriptorIO)?, timeout_sec=nil : C::TimeT?)
    readfds  ||= [] of FileDescriptorIO
    writefds ||= [] of FileDescriptorIO
    errorfds ||= [] of FileDescriptorIO
    ios = readfds+writefds+errorfds
    fdsets = {to_fdset(readfds), to_fdset(writefds), to_fdset(errorfds)}

    if timeout_sec
      timeout = C::TimeVal.new
      timeout.tv_sec = timeout_sec
      timeout.tv_usec = 0
      timeout_ptr = pointerof(timeout)
    else
      timeout_ptr = Pointer(C::TimeVal).null
    end

    readfdset, writefdset, errorfdset = fdsets
    nfds = ios.map(&.fd).max
    nfds += 1
    case C.select(nfds, pointerof(readfdset) as Void*, pointerof(writefdset) as Void*, pointerof(errorfdset) as Void*, timeout_ptr as Void*)
    when 0
      # TODO: better exception type
      raise "Timed out"
    when -1
      raise Errno.new("Error waiting with select()")
    else
      ios.find {|io| fdsets.any? {|fdset| fdset.is_set(io) } }.not_nil!
    end
  end

  private def self.to_fdset fds : Array(FileDescriptorIO)
    fdset = Process::FdSet.new
    fds.each do |io|
      fdset.set io
    end
    fdset
  end
end
