/++
	Some widgets that are included in the package.
+/
module qui.widgets;

import qui.qui;
import qui.utils;
import utils.misc;
import utils.lists;

/// Displays some text
///
/// And it can't handle new-line characters
///
/// If the text doesn't fit in width, it will move left-right
class TextLabelWidget : QWidget{
private:
	/// number of chars not displayed on left
	uinteger xOffset = 0;
	/// max xOffset
	uinteger maxXOffset;
	/// the text to display
	dstring _caption;
	/// if in the last timerEvent, xOffset was increased
	bool increasedXOffset = true;

	/// calculates the maxXOffset, and changes xOffset if it's above it
	void calculateMaxXOffset(){
		if (_caption.length <= size.width){
			maxXOffset = 0;
			xOffset = 0;
		}else{
			maxXOffset = _caption.length - _size.width;
			if (xOffset > maxXOffset)
				xOffset = maxXOffset;
		}
	}
protected:
	override void timerEvent(uinteger msecs){
		static uinteger accumulatedTime;
		if (maxXOffset > 0){
			accumulatedTime += msecs;
			if (xOffset >= maxXOffset)
				increasedXOffset = false;
			else if (xOffset == 0)
				increasedXOffset = true;
			while (accumulatedTime >= scrollTimer){
				accumulatedTime -= scrollTimer;
				if (increasedXOffset){
					if (xOffset < maxXOffset)
						xOffset ++;
				}else if (xOffset > 0)
					xOffset --;
				// request update
				requestUpdate();
			}
		}
	}
	
	override void resizeEvent(){
		calculateMaxXOffset;
		requestUpdate();
	}
	
	override void update(){
		_display.write(_caption.scrollHorizontal(xOffset, _size.width), textColor, backgroundColor);
	}

public:
	/// text and background colors
	Color textColor, backgroundColor;
	/// milliseconds after it scrolls 1 pixel, in case text too long to fit in 1 line
	uinteger scrollTimer;
	/// constructor
	this(dstring newCaption = ""){
		this.caption = newCaption;
		textColor = DEFAULT_FG;
		backgroundColor = DEFAULT_BG;
		this._size.maxHeight = 1;
		scrollTimer = 500;
	}

	/// the text to display
	@property dstring caption(){
		return _caption;
	}
	/// ditto
	@property dstring caption(dstring newCaption){
		_caption = newCaption;
		calculateMaxXOffset;
		// request update
		requestUpdate();
		return _caption;
	}
}

/// Displays a left-to-right progress bar.
/// 
/// Can also display text (just like TextLabelWidget)
class ProgressbarWidget : TextLabelWidget{
private:
	uinteger _max, _progress;
protected:
	override void update(){
		// if caption fits in width, center align it
		dstring text;
		if (_caption.length < _size.width)
			text = centerAlignText(_caption, _size.width);
		else
			text = _caption.scrollHorizontal(xOffset, _size.width);
		// number of chars to be colored in barColor
		uinteger fillCharCount = (_progress * _size.width) / _max;
		// line number on which the caption will be written
		for (uinteger i = 0,captionLineNumber = this._size.height / 2; i < this._size.height; i ++){
			_display.cursor = Position(0, i);
			if (i == captionLineNumber){
				_display.write(cast(dchar[])text[0 .. fillCharCount], backgroundColor, barColor);
				_display.write(cast(dchar[])text[fillCharCount .. text.length], barColor, backgroundColor);
			}else{
				if (fillCharCount)
					_display.fillLine(' ', backgroundColor, barColor, fillCharCount);
				if (fillCharCount < this._size.width)
					_display.fillLine(' ', barColor, backgroundColor);
			}
		}
		// write till _progress
		_display.write(cast(dchar[])text[0 .. fillCharCount], backgroundColor, barColor);
		// write the empty bar
		_display.write(cast(dchar[])text[fillCharCount .. text.length], barColor, backgroundColor);
	}
public:
	/// background color, and bar's color
	Color backgroundColor, barColor;
	/// constructor
	this(uinteger max = 100, uinteger progress = 0){
		_caption = null;
		this.max = max;
		this.progress = progress;
		// no max height limit on this one
		this._size.maxHeight = 0;

		barColor = DEFAULT_FG;
		backgroundColor = DEFAULT_BG;
	}
	/// The 'total', or the max-progress. getter
	@property uinteger max(){
		return _max;
	}
	/// The 'total' or the max-progress. setter
	@property uinteger max(uinteger newMax){
		_max = newMax;
		requestUpdate();
		return _max;
	}
	/// the amount of progress. getter
	@property uinteger progress(){
		return _progress;
	}
	/// the amount of progress. setter
	@property uinteger progress(uinteger newProgress){
		_progress = newProgress;
		requestUpdate();
		return _progress;
	}
}

/// To get single-line input from keyboard
class EditLineWidget : QWidget{
private:
	/// text that's been input-ed
	dchar[] _text;
	/// position of cursor
	uinteger _x;
	/// how many chars wont be displayed on left
	uinteger _scrollX;

	/// called to fix _scrollX and _x when input is changed or _x is changed
	void reScroll(){
		adjustScrollingOffset(_x, _size.width, _text.length, _scrollX);
	}
protected:
	/// override resize to re-scroll
	override void resizeEvent(){
		requestUpdate();
		reScroll;
	}
	override void mouseEvent(MouseEvent mouse){
		if (mouse.button == MouseEvent.Button.Left){
			_x = mouse.x + _scrollX;
		}
		requestUpdate();
		reScroll;
	}
	override void keyboardEvent(KeyboardEvent key){
		if (key.isChar){
			//insert that key
			if (key.key == '\b'){
				//backspace
				if (_x > 0){
					if (_x == _text.length){
						_text.length --;
					}else{
						_text = _text.deleteElement(_x-1);
					}
					_x --;
				}
			}else if (key.key != '\n'){
				if (_x == _text.length){
					//insert at end
					_text ~= cast(dchar)key.key;
				}else{
					_text = _text.insertElement([cast(dchar)key.key], _x);
				}
				_x ++;
			}
		}else{
			if (key.key == Key.LeftArrow && _x > 0){
				_x --;
			}else if (key.key == Key.RightArrow && _x < _text.length){
				_x ++;
			}else if (key.key == Key.Delete && _x < _text.length){
				_text = _text.deleteElement(_x);
			}
		}
		requestUpdate();
		reScroll;
	}
	override void update(){
		_display.write(cast(dstring)this._text.scrollHorizontal(cast(integer)_scrollX, _size.width),textColor,backgroundColor);
	}
public:
	/// background, text, caption, and caption's background colors
	Color backgroundColor, textColor;
	/// constructor
	this(dstring text = ""){
		this._text = cast(dchar[])text.dup;
		//specify min/max
		_size.minHeight = 1;
		_size.maxHeight = 1;
		// don't want tab key by default
		_wantsTab = false;
		// and input too, obvious
		_wantsInput = true;

		textColor = DEFAULT_FG;
		backgroundColor = DEFAULT_BG;
	}

	///The text that has been input-ed.
	@property dstring text(){
		return cast(dstring)_text.dup;
	}
	///The text that has been input-ed.
	@property dstring text(dstring newText){
		_text = cast(dchar[])newText.dup;
		// request update
		requestUpdate();
		return cast(dstring)newText;
	}
	// override cursor position
	override @property Position cursorPosition(){
		return Position(_x - _scrollX, 0);
	}
}

/// Can be used as a simple text editor, or to just display text
class MemoWidget : QWidget{
private:
	List!dstring _lines;
	/// how many characters/lines are skipped
	uinteger _scrollX, _scrollY;
	/// whether the cursor is, relative to line#0 character#0
	uinteger _cursorX, _cursorY;
	/// whether the text in it will be editable
	bool _enableEditing = true;
	/// used by widget itself to recalculate scrolling
	void reScroll(){
		// _scrollY
		adjustScrollingOffset(_cursorY, this._size.height, lineCount, _scrollY);
		// _scrollX
		adjustScrollingOffset(_cursorX, this._size.width, readLine(_cursorY).length, _scrollX);
	}
	/// used by widget itself to move cursor
	void moveCursor(uinteger x, uinteger y){
		_cursorX = x;
		_cursorY = y;
		
		if (_cursorY > lineCount)
			_cursorY = lineCount-1;
		if (_cursorX > readLine(_cursorY).length)
			_cursorX = readLine(_cursorY).length;
	}
	/// Reads a line from widgetLines
	dstring readLine(uinteger index){
		if (index >= _lines.length)
			return "";
		return _lines.read(index);
	}
	/// overwrites a line
	void overwriteLine(uinteger index, dstring line){
		if (index == _lines.length)
			_lines.append(line);
		else
			_lines.set(index,line);
		
	}
	/// deletes a line
	void removeLine(uinteger index){
		if (index < _lines.length)
			_lines.remove(index);
	}
	/// inserts a line
	void insertLine(uinteger index, dstring line){
		if (index == _lines.length)
			_lines.append(line);
		else
			_lines.insert(index, line);
	}
	/// adds a line
	void addLine(dstring line){
		_lines.append(line);
	}
	/// returns lines count
	@property uinteger lineCount(){
		return _lines.length+1;
	}
protected:
	override void update(){
		const uinteger count = lineCount;
		if (count > 0){
			//write lines to memo
			for (uinteger i = _scrollY; i < count && _display.cursor.y < _size.height; i++){
				_display.write(readLine(i).scrollHorizontal(_scrollX, this._size.width), 
					textColor, backgroundColor);
			}
		}
		_display.fill(' ', textColor, backgroundColor);
	}

	override void resizeEvent(){
		requestUpdate();
		reScroll();
	}
	
	override void mouseEvent(MouseEvent mouse){
		//calculate mouse position, relative to scroll
		mouse.x = mouse.x + cast(int)_scrollX;
		mouse.y = mouse.y + cast(int)_scrollY;
		if (mouse.button == mouse.Button.Left){
			requestUpdate();
			moveCursor(mouse.x, mouse.y);
		}else if (mouse.button == mouse.Button.ScrollDown){
			if (_cursorY+1 < lineCount){
				requestUpdate();
				moveCursor(_cursorX, _cursorY + 4);
				reScroll();
			}
		}else if (mouse.button == mouse.Button.ScrollUp){
			if (_cursorY > 0){
				requestUpdate();
				if (_cursorY < 4){
					moveCursor(_cursorX, 0);
				}else{
					moveCursor(_cursorX, _cursorY - 4);
				}
				reScroll();
			}
		}
	}
	// too big of a mess to be dealt with right now, TODO try to make this shorter
	override void keyboardEvent(KeyboardEvent key){
		if (key.isChar){
			if (_enableEditing){
				requestUpdate();
				dstring currentLine = readLine(_cursorY);
				//check if backspace
				if (key.key == '\b'){
					//make sure that it's not the first line, first line cannot be removed
					if (_cursorY > 0){
						//check if has to remove a '\n'
						if (_cursorX == 0){
							_cursorY --;
							//if line's not empty, append it to previous line
							_cursorX = readLine(_cursorY).length;
							if (currentLine != ""){
								//else, append this line to previous
								overwriteLine(_cursorY, readLine(_cursorY)~currentLine);
							}
							removeLine(_cursorY+1);
						}else{
							overwriteLine(_cursorY, cast(dstring)deleteElement(cast(dchar[])currentLine,_cursorX-1));
							_cursorX --;
						}
					}else if (_cursorX > 0){
						overwriteLine(_cursorY, cast(dstring)deleteElement(cast(dchar[])currentLine,_cursorX-1));
						_cursorX --;
					}
					
				}else if (key.key == '\n'){
					//insert a newline
					if (_cursorX == readLine(_cursorY).length){
						if (_cursorY >= lineCount - 1){
							_lines.append("");
						}else{
							insertLine(_cursorY + 1,"");
						}
					}else{
						dstring[2] line;
						line[0] = readLine(_cursorY);
						line[1] = line[0][_cursorX .. line[0].length];
						line[0] = line[0][0 .. _cursorX];
						overwriteLine(_cursorY, line[0]);
						if (_cursorY >= lineCount - 1){
							_lines.append(line[1]);
						}else{
							insertLine(_cursorY + 1, line[1]);
						}
					}
					_cursorY ++;
					_cursorX = 0;
				}else if (key.key == '\t'){
					//convert it to 4 spaces
					overwriteLine(_cursorY, cast(dstring)insertElement(cast(dchar[])currentLine,cast(dchar[])"    ",_cursorX));
					_cursorX += 4;
				}else{
					//insert that char
					overwriteLine(_cursorY, cast(dstring)insertElement(cast(dchar[])currentLine,[cast(dchar)key.key],_cursorX));
					_cursorX ++;
				}
			}
		}else{
			if (key.key == Key.Delete && _enableEditing){
				requestUpdate();
				//check if is deleting \n
				if (_cursorX == readLine(_cursorY).length && _cursorY+1 < lineCount){
					//merge next line with this one
					dchar[] line = cast(dchar[])readLine(_cursorY)~readLine(_cursorY+1);
					overwriteLine(_cursorY, cast(dstring)line);
					//remove next line
					removeLine(_cursorY+1);
				}else if (_cursorX < readLine(_cursorY).length){
					dchar[] line = cast(dchar[])readLine(_cursorY);
					line = line.deleteElement(_cursorX);
					overwriteLine(_cursorY, cast(dstring)line);
				}
			}else if (key.key == Key.DownArrow){
				if (_cursorY+1 < lineCount){
					requestUpdate();
					_cursorY ++;
				}
			}else if (key.key == Key.UpArrow){
				if (_cursorY > 0){
					requestUpdate();
					_cursorY --;
				}
			}else if (key.key == Key.LeftArrow){
				if ((_cursorY >= 0 && _cursorX > 0) || (_cursorY > 0 && _cursorX == 0)){
					requestUpdate();
					if (_cursorX == 0){
						_cursorY --;
						_cursorX = readLine(_cursorY).length;
					}else{
						_cursorX --;
					}
				}
			}else if (key.key == Key.RightArrow){
				requestUpdate();
				if (_cursorX == readLine(_cursorY).length){
					if (_cursorY+1 < lineCount){
						_cursorX = 0;
						_cursorY ++;
						_scrollX = 0;
					}
				}else{
					_cursorX ++;
				}
			}
		}
		// I'll use this this time not to move the cursor, but to fix the cursor position
		moveCursor(_cursorX,_cursorY);
		reScroll();
	}
public:
	/// background and text colors
	Color backgroundColor, textColor;
	/// constructor
	this(bool allowEditing = true){
		_lines = new List!dstring;
		_scrollX = 0;
		_scrollY = 0;
		_cursorX = 0;
		_cursorY = 0;
		this.editable = allowEditing;

		textColor = DEFAULT_FG;
		backgroundColor = DEFAULT_BG;
	}
	~this(){
		.destroy(_lines);
	}
	
	///returns a list of lines in memo
	///
	///To modify the content, just modify it in the returned list
	///
	///class `List` is defined in `utils.lists.d`
	@property List!dstring lines(){
		return _lines;
	}
	///Returns true if memo's contents cannot be modified, by user
	@property bool editable(){
		return _enableEditing;
	}
	///sets whether to allow modifying of contents (false) or not (true)
	@property bool editable(bool newPermission){
		_wantsTab = newPermission;
		_wantsInput = newPermission;
		return _enableEditing = newPermission;
	}
	/// override cursor position
	override @property Position cursorPosition(){
		return	_enableEditing ? Position(_cursorX - _scrollX, _cursorY - _scrollY) : Position(-1,-1);
	}
}

/// Displays an un-scrollable log
/// 
/// It's content cannot be modified by user, like a MemoWidget with editing disabled, but automatically scrolls down as new lines 
/// are added, and it wraps long lines.
class LogWidget : QWidget{
private:
	/// stores the logs
	List!dstring _logs;
	/// The index in _logs where the oldest added line is
	uinteger _startIndex;
	/// the maximum number of lines to store
	uinteger _maxLines;
	/// Returns: line at an index
	dstring getLine(uinteger index){
		if (index >= _logs.length)
			return "";
		return _logs.read((index + _startIndex) % _maxLines);
	}
	/// wrap a line
	dstring[] wrapLine(dstring str){
		dstring[] r;
		str = str.dup;
		while (str.length > 0){
			r ~= _size.width > str.length ? str : str[0 .. _size.width];
			str = _size.width < str.length ? str[_size.width .. $] : [];
		}
		return r;
	}
protected:
	override void update(){
		_display.colors(textColor, backgroundColor);
		integer lastY = _size.height;
		for (integer i = _logs.length-1; i >= 0; i --){
			dstring line = getLine(i);
			dstring[] wrappedLine = wrapLine(line);
			if (wrappedLine.length == 0)
				continue;
			if (lastY < wrappedLine.length)
				wrappedLine = wrappedLine[wrappedLine.length - lastY .. $];
			immutable integer startY = lastY - wrappedLine.length;
			foreach (lineno, currentLine; wrappedLine){
				_display.cursor = Position(0, lineno + startY);
				_display.write(currentLine);
				if (currentLine.length < _size.width)
					_display.fillLine(' ', textColor, backgroundColor);
			}
			lastY = startY;
		}
		_display.cursor = Position(0, 0);
		foreach (y; 0 .. lastY)
			_display.fillLine(' ', textColor, backgroundColor);
	}
	
	override void resizeEvent() {
		requestUpdate();
	}
public:
	/// background and text color
	Color backgroundColor, textColor;
	/// constructor
	this(uinteger maxLen=100){
		_maxLines = maxLen;
		_logs = new List!dstring;
		_startIndex = 0;

		textColor = DEFAULT_FG;
		backgroundColor = DEFAULT_BG;
	}
	~this(){
		_logs.destroy;
	}
	
	///adds string to the log, and scrolls down to it.
	/// newline character is not allowed
	void add(dstring item){
		//check if needs to overwrite
		if (_logs.length > _maxLines){
			_startIndex = (_startIndex + 1) % _maxLines;
			_logs.set(_startIndex, item);
		}else
			_logs.append(item);
		requestUpdate();
	}
	///clears the log
	void clear(){
		_logs.clear;
		requestUpdate();
	}
}

/// Just occupies some space. Use this to put space between widgets
/// 
/// To specify the size, use the minHeight, maxHeight, minWidth, and maxWidth. only specifying the width and/or height will have no effect
class SplitterWidget : QWidget{
protected:
	override void resizeEvent() {
		requestUpdate();
	}
	
	override void update(){
		_display.fill(' ',DEFAULT_FG, color);
	}
public:
	/// color of this widget
	Color color;
	/// constructor
	this(){
		this.color = DEFAULT_BG;
	}
}