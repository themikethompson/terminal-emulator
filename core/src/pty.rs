use nix::pty::{openpty, Winsize};
use nix::unistd::{fork, setsid, ForkResult};
use std::os::fd::{AsRawFd, FromRawFd, RawFd};
use std::io::{self, Read, Write};
use std::os::unix::process::CommandExt;
use std::process::Command;

pub struct Pty {
    pub master: RawFd,
    pub slave: RawFd,
    pub child_pid: Option<nix::unistd::Pid>,
}

impl Pty {
    /// Create a new PTY with the specified dimensions
    pub fn new(cols: u16, rows: u16) -> io::Result<Self> {
        let winsize = Winsize {
            ws_row: rows,
            ws_col: cols,
            ws_xpixel: 0,
            ws_ypixel: 0,
        };

        let pty_result = openpty(Some(&winsize), None)
            .map_err(|e| io::Error::new(io::ErrorKind::Other, e))?;

        Ok(Pty {
            master: pty_result.master.as_raw_fd(),
            slave: pty_result.slave.as_raw_fd(),
            child_pid: None,
        })
    }

    /// Spawn a shell process in the PTY
    pub fn spawn_shell(&mut self, shell: Option<&str>) -> io::Result<()> {
        let shell_path = shell.unwrap_or("/bin/zsh");

        match unsafe { fork() } {
            Ok(ForkResult::Parent { child }) => {
                // Parent process - store child PID
                self.child_pid = Some(child);
                // Close slave in parent
                unsafe { libc::close(self.slave) };
                Ok(())
            }
            Ok(ForkResult::Child) => {
                // Child process
                // Create new session
                setsid().expect("Failed to create new session");

                // Redirect stdin/stdout/stderr to slave PTY
                unsafe {
                    libc::dup2(self.slave, libc::STDIN_FILENO);
                    libc::dup2(self.slave, libc::STDOUT_FILENO);
                    libc::dup2(self.slave, libc::STDERR_FILENO);

                    // Close master and slave in child
                    libc::close(self.master);
                    libc::close(self.slave);
                }

                // Execute shell
                let err = Command::new(shell_path)
                    .env("TERM", "xterm-256color")
                    .exec();

                // If exec returns, it failed
                eprintln!("Failed to execute shell: {}", err);
                std::process::exit(1);
            }
            Err(e) => Err(io::Error::new(io::ErrorKind::Other, e)),
        }
    }

    /// Read data from the PTY master
    pub fn read(&self, buffer: &mut [u8]) -> io::Result<usize> {
        let mut file = unsafe { std::fs::File::from_raw_fd(self.master) };
        let result = file.read(buffer);
        std::mem::forget(file); // Don't close the fd
        result
    }

    /// Write data to the PTY master
    pub fn write(&self, data: &[u8]) -> io::Result<usize> {
        let mut file = unsafe { std::fs::File::from_raw_fd(self.master) };
        let result = file.write(data);
        std::mem::forget(file); // Don't close the fd
        result
    }

    /// Resize the PTY
    pub fn resize(&self, cols: u16, rows: u16) -> io::Result<()> {
        let winsize = Winsize {
            ws_row: rows,
            ws_col: cols,
            ws_xpixel: 0,
            ws_ypixel: 0,
        };

        unsafe {
            if libc::ioctl(self.master, libc::TIOCSWINSZ, &winsize) == -1 {
                return Err(io::Error::last_os_error());
            }
        }

        Ok(())
    }

    /// Get the master file descriptor
    pub fn master_fd(&self) -> RawFd {
        self.master
    }
}

impl Drop for Pty {
    fn drop(&mut self) {
        unsafe {
            libc::close(self.master);
        }

        // Send SIGHUP to child process if it exists
        if let Some(pid) = self.child_pid {
            let _ = nix::sys::signal::kill(pid, nix::sys::signal::Signal::SIGHUP);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pty_creation() {
        let pty = Pty::new(80, 24);
        assert!(pty.is_ok());
    }
}
