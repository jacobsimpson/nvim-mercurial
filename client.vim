" Vimscript code that is used by an isolated instance of nvim.
"
" During a commit, hg will call may call an editor in order to allow the user
" to edit the commit message. When `hg commit` is called from inside nvim, it
" is not desireable to start another instance of nvim to edit the commit
" message. So, the goal is to open the commit message in the running instance.
" In order to make that happen, there has to be an editor specified that will:
"     1. Signal the current nvim instance to open the commit message for
"     editing.
"     2. Wait until the commit message buffer is closed before continuing.
"     3. Return any errors that occur during editing.
" So, to solve that problem, I use an instance of nvim as an interpreter, not
" an editor. What happens is:
"     1. Start an nvim instance headless, and run this vimscript.
"     2. This vimscript will open a socket connection back to the containing
"     nvim instance.
"     3. This vimscript will signal to open the commit message in a buffer.
"     4. This vimscript will poll, waiting for that buffer to be closed.
"     5. If there is an error, this script will exit nvim with an error
"     status.
"

function! ConnectToRemoteNeovim()
    let server_socket = $NVIM_SERVERNAME
    if empty(server_socket)
        echo "NVIM_SERVERNAME is empty."
        execute ":cq"
    endif
    let commit_message_filename = expand("%")
    let remote_command = printf(':lua MercurialEditCommitMessage("%s", "%s")', commit_message_filename, v:servername)
    try
        let channel = sockconnect('pipe', server_socket, {'rpc': 1})
        let result = rpcrequest(channel, 'nvim_command', remote_command)
        let result = 1
        while result
            sleep 100m
            let result = rpcrequest(channel, 'nvim_exec_lua', 'return MercurialGetResult()', [])
        endwhile
        call chanclose(channel)
        execute ":q!"
    catch /.*/
        echo v:exception
        " :cq! will exit this instance of vim with a non-zero exit status.
        execute ":cq!"
    endtry
endfunction

call ConnectToRemoteNeovim()
