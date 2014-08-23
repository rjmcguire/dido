module dido.command;


// Editor commands (abstracted for macros)

enum CommandType
{
    MOVE_LEFT,
    MOVE_RIGHT,
    MOVE_UP,
    MOVE_DOWN,
    MOVE_LINE_END,
    MOVE_LINE_BEGIN,
    TOGGLE_FULLSCREEN,
    ENTER_COMMANDLINE_MODE, 
    EXIT, 
    RETURN,
    INSERT_CHAR,
    BACKSPACE
}

struct Command
{
    this(CommandType type_)
    {
        type = type_;
    }

    this(CommandType type_, dchar ch_)
    {
        type = type_;
        ch = ch_;
    }

    CommandType type;
    dchar ch;
}

