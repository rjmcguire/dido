module dido.panel;

import std.conv;
import std.path;

import gfm.math;
import gfm.sdl2;

import dido.window;
import dido.selection;
import dido.buffer;
import dido.font;

class Panel
{
public:

    abstract void render(SDL2Renderer renderer);

    abstract void reflow(box2i availableSpace, int charWidth, int charHeight);

    final box2i position() pure const nothrow
    {
        return _position;
    }

private:
    box2i _position;
}

class MainPanel : Panel
{
public:
    override void reflow(box2i availableSpace, int charWidth, int charHeight)
    {
        _position = availableSpace;

        foreach(child; children)
            child.reflow(availableSpace, charWidth, charHeight);
    }

    override void render(SDL2Renderer renderer)
    {
        renderer.setViewportFull();
        renderer.setColor(23, 23, 23, 255);
        renderer.clear();
        foreach(child; children)
            child.render(renderer);
    }

    Panel[] children;
}

class MenuPanel : Panel
{
    override void reflow(box2i availableSpace, int charWidth, int charHeight)
    {
        _position = availableSpace;
        _position.max.y = availableSpace.min.y + 8 + charHeight;
    }

    override void render(SDL2Renderer renderer)
    {
        renderer.setColor(14, 14, 14, 230);
        renderer.fillRect(_position.min.x, _position.min.y,  _position.width, _position.height);
    }
}

class SolutionPanel : Panel
{
public:
    override void reflow(box2i availableSpace, int charWidth, int charHeight)
    {
        _position = availableSpace;
        int widthOfSolutionExplorer = (250 + availableSpace.width / 3) / 2;
        _position.max.x = widthOfSolutionExplorer;
        _position.min.y = (8 + charHeight);
        _position.max.y -= (8 + charHeight);
    }

    override void render(SDL2Renderer renderer)
    {
        renderer.setViewport(_position.min.x, _position.min.y, _position.width, _position.height);
        renderer.setColor(34, 34, 34, 255);
        renderer.fillRect(0, 0, _position.width, _position.height);

        int itemSpace = _font.charHeight() + 12;
        int marginX = 16;
        int marginY = 16;
        
        for(int i = 0; i < cast(int)_buffers.length; ++i)
        {   
            renderer.setColor(25, 25, 25, 255);
            int rectMargin = 4;
            renderer.fillRect(marginX - rectMargin, marginY - rectMargin + i * itemSpace, _position.width - 2 * (marginX - rectMargin), itemSpace - 4);
        }

        for(int i = 0; i < cast(int)_buffers.length; ++i)
        {
            if (i == _bufferSelect)
                _font.setColor(255, 255, 255, 255);
            else
                _font.setColor(200, 200, 200, 255);
            _font.renderString(_prettyName[i], marginX, marginY + i * itemSpace);
        }

        renderer.setViewportFull();
    }

    void updateState(Font font, Buffer[] buffers, int bufferSelect)
    {
        _buffers = buffers;
        _prettyName.length = buffers.length;
        for(int i = 0; i < cast(int)buffers.length; ++i)
        {
            _prettyName[i] = baseName(buffers[i].filePath());
        }
        _font = font;
        _bufferSelect = bufferSelect;
    }

private:
    string[] _prettyName;
    Buffer[] _buffers;
    Font _font;
    int _bufferSelect;
}

class CommandLinePanel : Panel
{
public:

    this(Font font)
    {
        _font = font;
        currentCommandLine = "";
        statusLine = "";
    }

    override void reflow(box2i availableSpace, int charWidth, int charHeight)
    {
        _position = availableSpace;
        _position.min.y = availableSpace.max.y - (8 + charHeight);

        _charWidth = charWidth;
    }

    override void render(SDL2Renderer renderer)
    {
        renderer.setColor(14, 14, 14, 230);
        renderer.fillRect(_position.min.x, _position.min.y,  _position.width, _position.height);

        {
            // commandline bar at bottom

            int textPosx = _position.min.x + 4 + _charWidth;
            int textPosy = _position.min.y + 4;

            if (_commandLineMode)
            {
                _font.setColor(255, 255, 0, 255);
                _font.renderString(":", _position.min.x + 4, _position.min.y + 4);
                _font.setColor(255, 255, 128, 255);
                _font.renderString(currentCommandLine, textPosx, textPosy);
            }
            else
            {
                // Write status line
                _font.setColor(statusColor.r, statusColor.g, statusColor.b, 255);
                _font.renderString(statusLine, textPosx, textPosy);
            }
        }

    }

    void updateState(bool commandLineMode)
    {
        _commandLineMode = commandLineMode;
    }

    dstring currentCommandLine;
    dstring statusLine;
    vec3i statusColor;

private:
    Font _font;
    int _charWidth;
    bool _commandLineMode;

}

class TextArea : Panel
{
public:

    override void reflow(box2i availableSpace, int charWidth, int charHeight)
    {
        _position = availableSpace;
        int widthOfSolutionExplorer = (250 + availableSpace.width / 3) / 2;

        _position.min.x = widthOfSolutionExplorer;
        _position.min.y = (8 + charHeight);
        _position.max.y -= (8 + charHeight);

        _charWidth = charWidth;
        _charHeight = charHeight; 
    }

    override void render(SDL2Renderer renderer)
    {
        renderer.setViewport(_position.min.x, _position.min.y, _position.width, _position.height);

        int widthOfLineNumberMargin = _charWidth * 6;
        int widthOfLeftScrollbar = 12;
        int marginScrollbar = 4;

        renderer.setColor(28, 28, 28, 255);
        renderer.fillRect(0, 0, widthOfLineNumberMargin, _position.height);

        renderer.setColor(34, 34, 34, 128);
        renderer.fillRect(_position.width - marginScrollbar - widthOfLeftScrollbar, 
                          marginScrollbar, 
                          widthOfLeftScrollbar, 
                          _position.height - marginScrollbar * 2);

        int marginEditor = 16;

        int editPosX = -_cameraX + widthOfLineNumberMargin + marginEditor;
        int editPosY = -_cameraY + marginEditor;

        int firstVisibleLine = max(0, _cameraY / _charHeight - 1);
        int firstNonVisibleLine = min(_buffer.numLines(), 1 + (_cameraY + _position.height + _charHeight - 1) / _charHeight);

        for (int i = firstVisibleLine; i < firstNonVisibleLine; ++i)
        {
            dstring line = _buffer.line(i);
            dstring lineNumber = to!dstring(i + 1) ~ " ";
            while (lineNumber.length < 6)
            {
                lineNumber = " "d ~ lineNumber;
            }

            _font.setColor(49, 97, 107, 160);
            _font.renderString(lineNumber,  0,  0 -_cameraY + marginEditor + i * _charHeight);


            int posXInChars = 0;
            int posY = editPosY + i * _charHeight;
            
            foreach(dchar ch; line)
            {
                int widthOfChar = 1;
                switch (ch)
                {
                    case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9':
                        _font.setColor(255, 200, 200);
                        break;

                    case '+', '-', '=', '>', '<', '^', ',', '$', '|', '&', '`', '/', '@', '.', '"', '[', ']', '?', ':', '\'', '\\':
                        _font.setColor(255, 255, 106);
                        break;

                    case '(', ')', ';':
                        _font.setColor(255, 255, 150);
                        break;

                    case '{':
                        _font.setColor(108, 108, 128);
                        break;

                    case '}':
                        _font.setColor(108, 108, 138);
                        break;

                    case '\n':
                        ch = ' '; //0x2193; // down arrow
                        _font.setColor(40, 40, 40);
                        break;

                    case '\t':
                        ch = 0x2192;
                        _font.setColor(80, 60, 70);
                        int tabLength = 1;//4; not working yet
                        widthOfChar = tabLength - posXInChars % tabLength;
                        break;

                    case ' ':
                        ch = 0x2D1;
                        _font.setColor(60, 60, 70);
                        break;

                    default:
                        _font.setColor(250, 250, 250);
                        break;
                }

                box2i visibleBox = box2i(0, 0, _position.width, _position.height);
                int posX = editPosX + posXInChars * _charWidth;
                box2i charBox = box2i(posX, posY, posX + _charWidth, posY + _charHeight);
                if (visibleBox.intersects(charBox))
                    _font.renderChar(ch, posX, posY);
                posXInChars += widthOfChar;
            }
        }

        // draw cursors
        SelectionSet selset = _buffer.selectionSet();
        foreach(Selection sel; selset.selections)
        {
            renderSelection(renderer, editPosX, editPosY, sel, _drawCursors);
        }

        renderer.setViewportFull();
    }

    void setState(Font font, Buffer buffer, bool drawCursors)
    {
        _buffer = buffer;
        _font = font;
        _drawCursors = drawCursors;
    }

    void clearCamera()
    {
        _cameraX = 0;
        _cameraY = 0;
    }

    void moveCamera(int dx, int dy)
    {
        _cameraX += dx;
        _cameraY += dy;
        normalizeCamera();       
    }

    void normalizeCamera()
    {
        if (_cameraX < 0)
            _cameraX = 0;
        if (_cameraY < 0)
            _cameraY = 0;
    }

private:
    int _cameraX = 0;
    int _cameraY = 0;
    int _charWidth;
    int _charHeight;
    Buffer _buffer;    
    Font _font;
    bool _drawCursors;

    void renderSelection(SDL2Renderer renderer, int offsetX, int offsetY, Selection selection, bool drawCursors)
    {
        // draw the cursor part
        if (drawCursors)
        {
            int startX = offsetX + selection.anchor.cursor.column * _font.charWidth();
            int startY = offsetY + selection.anchor.cursor.line * _font.charHeight();

            renderer.setColor(255, 255, 255, 255);
            renderer.fillRect(startX, startY, 1, _font.charHeight() - 1);
        }

        if (selection.hasSelectedArea)
        {
            int stopX = offsetX + selection.edge.cursor.column * _font.charWidth();
            int stopY = offsetY + selection.edge.cursor.line * _font.charHeight();

            // draw the cursor part
            renderer.setColor(128, 128, 128, 255);
            renderer.fillRect(stopX, stopY, 1, _font.charHeight() - 1);
        }

        // TODO draw extent
    }
}