﻿module qui;

import misc;
import lists;
import baseconv;//used for hexadecimal colors
import std.stdio;//used by QTheme.themeToFile
import arsd.terminal;

///Mouse Click, or Ms Wheel scroll event
struct MouseClick{
	enum Button{
		Left,
		ScrollUp,
		ScrollDown,
		Right,
	}
	Button mouseButton;
	uinteger x;
	uinteger y;
}

///Key press event, somewhat similar to arsd.terminal.KeyPress
struct KeyPress{
	dchar key;
	bool isChar(){
		return !(key >= NonCharKey.min && key <= NonCharKey.max);
	}
	enum NonCharKey{
		escape = 0x1b + 0xF0000,
		F1 = 0x70 + 0xF0000,
		F2 = 0x71 + 0xF0000,
		F3 = 0x72 + 0xF0000,
		F4 = 0x73 + 0xF0000,
		F5 = 0x74 + 0xF0000,
		F6 = 0x75 + 0xF0000,
		F7 = 0x76 + 0xF0000,
		F8 = 0x77 + 0xF0000,
		F9 = 0x78 + 0xF0000,
		F10 = 0x79 + 0xF0000,
		F11 = 0x7A + 0xF0000,
		F12 = 0x7B + 0xF0000,
		LeftArrow = 0x25 + 0xF0000,
		RightArrow = 0x27 + 0xF0000,
		UpArrow = 0x26 + 0xF0000,
		DownArrow = 0x28 + 0xF0000,
		Insert = 0x2d + 0xF0000,
		Delete = 0x2e + 0xF0000,
		Home = 0x24 + 0xF0000,
		End = 0x23 + 0xF0000,
		PageUp = 0x21 + 0xF0000,
		PageDown = 0x22 + 0xF0000,
	}
}

///A 24 bit, RGB, color
alias RGBColor = RGB;

///To store position for widgets
struct Position{
	uinteger x, y;
}
///To store size for widgets
struct Size{
	uinteger width, height;
	uinteger minHeight = 0, minWidth = 0;//0 = no limit
	uinteger maxHeight = 0, maxWidth = 0;
}
///Cell, character in terminal is a Cell, that has it's own background color, and foreground color
struct Cell{
	char c;
	RGBColor textColor;
	RGBColor bgColor;
}

///Used by QWidget to retreive colors from QTheme
alias GetColorFunction = RGBColor delegate(string forWhichWidget, string whichColor);
alias GetColorsFunction = RGBColor[] delegate(string whichColor);


///base class for all widgets, including layouts and QTerminal
abstract class QWidget{
protected:
	Position widgetPosition;
	Size widgetSize;
	string widgetCaption;
	bool widgetShow = true;
	bool needsUpdate = true;
	string widgetName = null;//should be initialized in `this()`

	uinteger widgetSizeRatio = 1;

	//widget uses these to retreive colors from theme
	GetColorFunction getColor;
	GetColorsFunction getColors;
public:
	///called by owner when mouse is clicked with cursor on this widget
	abstract void onClick(MouseClick mouse);
	///called by owner when widget is selected and a key is pressed
	abstract void onKeyPress(KeyPress key);
	///called when the owner is redrawing, return false if no need to redraw
	abstract bool update(ref Matrix display);///return true to indicate that it has to be redrawn, else, make changes in display

	//properties:
	@property string name(){
		return widgetName;
	}

	@property string caption(){
		return widgetCaption;
	}
	@property string caption(string newCaption){
		needsUpdate = true;
		return widgetCaption = newCaption;
	}

	@property Position position(){
		return widgetPosition;
	}
	@property Position position(Position newPosition){
		return widgetPosition = newPosition;
	}

	@property uinteger sizeRatio(){
		return widgetSizeRatio;
	}
	@property uinteger sizeRatio(uinteger newRatio){
		needsUpdate = true;
		return widgetSizeRatio = newRatio;
	}

	@property bool visible(){
		return widgetShow;
	}
	@property bool visible(bool visibility){
		needsUpdate = true;
		return widgetShow = visibility;
	}

	@property GetColorFunction onGetColor(GetColorFunction newGetColor){
		return getColor = newGetColor;
	}

	@property GetColorsFunction onGetColors(GetColorsFunction newGetColors){
		return getColors = newGetColors;
	}

	@property Size size(){
		return widgetSize;
	}
	@property Size size(Size newSize){
		//check if height or width < min
		if (newSize.minWidth > 0 && newSize.width < newSize.minWidth){
			return widgetSize;
		}else if (newSize.maxWidth > 0 && newSize.width > newSize.maxWidth){
			return widgetSize;
		}else if (newSize.minHeight > 0 && newSize.height < newSize.minHeight){
			return widgetSize;
		}else if (newSize.maxHeight > 0 && newSize.height > newSize.maxHeight){
			return widgetSize;
		}else{
			needsUpdate = true;
			return widgetSize = newSize;
		}
	}
}

///name: `layout`; Used to contain widgets
class QLayout : QWidget{
private:
	QWidget[] widgetList;
	QWidget activeWidget;
	LayoutDisplayType layoutType;

	RGBColor backColor;
	RGBColor foreColor;
	Cell emptySpace;
	/* Just a note: Layouts do not use these variables inherited from QWidget:
	 * widgetCaption
	 * needsUpdate
	 * 
	 * They have no caption, and needsUpdate is determined by child widgets, when update is called
	*/

	void recalculateWidgetsSize(){
		uinteger ratioTotal = 0;
		Size newSize;
		//calculate total ratio
		foreach (currentWidget; widgetList){
			ratioTotal += currentWidget.sizeRatio;
		}
		Position newPosition;
		uinteger newWidth = 0, newHeight = 0;
		uinteger availableWidth = widgetSize.width;
		uinteger availableHeight = widgetSize.height;
		
		if (layoutType == LayoutDisplayType.Vertical){
			//make space for new widget
			foreach(w; widgetList){
				//if a widget is not visible, skip it
				if (w.visible){
					//recalculate position
					newPosition.x = widgetPosition.x;//x axis is always same, cause this is a vertical (not horizontal) layout
					if (newHeight > 0){
						newPosition.y += newHeight+1;//add previous widget's height to get new y axis position
					}else{
						newPosition.y = 0;
					}
					w.position = newPosition;
					//recalculate height
					newHeight = ratioToRaw(w.sizeRatio, ratioTotal, availableHeight);
					if (w.size.minHeight > 0 && newHeight < w.size.minHeight){
						newHeight = w.size.minHeight;
					}else if (w.size.maxHeight > 0 && newHeight > w.size.maxHeight){
						newHeight = w.size.maxHeight;
					}
					//recalculate width
					newWidth = widgetSize.width;//default is max
					//compare with min & max
					if (w.size.minWidth > 0 && newWidth < w.size.minWidth){
						//although there isn't that much width, still assign it, that will be dealt with later
						newWidth = w.size.minWidth;
					}else if (w.size.maxWidth > 0 && newWidth > w.size.maxWidth){
						newWidth = w.size.maxWidth;
					}
					//check if there's not enough space available, then make it invisible
					if (newWidth > availableWidth || newHeight > availableHeight){
						newWidth = 0;
						newHeight = 0;
						w.visible = false;
						continue;
					}
					//apply new size
					newSize = w.size;//to get min and max values
					newSize.height = newHeight;
					newSize.width = newWidth;
					w.size = newSize;
					//now the new size has been assigned, calculate amount of space & ratios left
					availableHeight -= newHeight;
					ratioTotal -= w.sizeRatio;
				}
			}
		}else if (layoutType == LayoutDisplayType.Horizontal){
			//make space for new widget
			foreach(w; widgetList){
				//if a widget is not visible, skip it
				if (w.visible){
					//recalculate position
					newPosition.y = widgetPosition.y;//x axis is always same, cause this is a vertical (not horizontal) layout
					if (newWidth > 0){
						newPosition.x += newWidth+1;//add previous widget's height to get new y axis position
					}else{
						newPosition.x = 0;
					}
					w.position = newPosition;
					//recalculate width
					newWidth = ratioToRaw(w.sizeRatio, ratioTotal, availableWidth);
					if (w.size.minWidth > 0 && newWidth < w.size.minWidth){
						newWidth = w.size.minWidth;
					}else if (w.size.maxWidth > 0 && newWidth > w.size.maxWidth){
						newWidth = w.size.maxWidth;
					}
					//recalculate height
					newHeight = widgetSize.height;//default is max
					//compare with min & max
					if (w.size.minHeight > 0 && newHeight < w.size.minHeight){
						//although there isn't that much width, still assign it, that will be dealt with later
						newHeight = w.size.minHeight;
					}else if (w.size.maxHeight > 0 && newHeight > w.size.maxHeight){
						newHeight = w.size.maxHeight;
					}
					//check if there's not enough space available, then make it invisible
					if (newWidth > availableWidth || newHeight > availableHeight){
						newWidth = 0;
						newHeight = 0;
						w.visible = false;
						continue;
					}
					//apply new size
					newSize = w.size;//to get min and max values
					newSize.height = newHeight;
					newSize.width = newWidth;
					w.size = newSize;
					//now the new size has been assigned, calculate amount of space & ratios left
					availableHeight -= newHeight;
					ratioTotal -= w.sizeRatio;
				}
			}
		}
	}

public:
	enum LayoutDisplayType{
		Vertical,
		Horizontal,
	}
	this(LayoutDisplayType type){
		widgetName = "layout";
		layoutType = type;
		activeWidget = null;
		if (getColor){
			emptySpace.bgColor = getColor(name, "background");
			emptySpace.textColor = getColor(name, "text");
		}else{
			emptySpace.bgColor = hexToColor("000000");
			emptySpace.textColor = hexToColor("00FF00");
		}
		emptySpace.c = ' ';
	}

	void addWidget(QWidget widget){
		//set getColor(s)
		widget.onGetColor = getColor;
		widget.onGetColors = getColors;
		//add it to array
		widgetList.length++;
		widgetList[widgetList.length-1] = widget;
		//recalculate all widget's size to adjust
		recalculateWidgetsSize();
	}

	void onClick(MouseClick mouse){
		//check on which widget the cursor was on
		Position p;
		Size s;
		uinteger i;
		QWidget widget;
		for (i = 0; i < widgetList.length; i++){
			widget = widgetList[i];
			p = widget.position;
			s = widget.size;
			//check x-axis
			if (mouse.x >= p.x && mouse.x < p.x + s.width){
				//check y-axis
				if (mouse.y >= p.y && mouse.y < p.y + s.height){
					//call onClick
					widget.onClick(mouse);
					//mark this widget as active
					activeWidget = widget;
					break;
				}
			}
		}
	}
	void onKeyPress(KeyPress key){
		//check active widget, call onKeyPress
		if (activeWidget){
			activeWidget.onKeyPress(key);
		}
	}
	bool update(ref Matrix display){
		//go through all widgets, check if they need update, update them
		bool updated = false;
		Matrix wDisplay = new Matrix(1,1,emptySpace);
		foreach(widget; widgetList){
			if (widget.visible){
				wDisplay.changeSize(widget.size.width, widget.size.height, emptySpace);
				wDisplay.setWriteLimits(0, 0, widget.size.width, widget.size.height);//to prevent writing outside limits
				if (widget.update(wDisplay)){
					display.insert(wDisplay, widget.position.x, widget.position.y);
					updated = true;
				}
			}
		}
		return updated;
	}
}

class QTerminal : QLayout{
private:
	Terminal terminal;
	RealTimeConsoleInput input;
	Matrix termDisplay;
	bool isRunning = false;

public:
	this(string caption = "QUI Text User Interface", LayoutDisplayType displayType = LayoutDisplayType.Vertical){
		super(displayType);
		//create terminal & input
		terminal = Terminal(ConsoleOutputType.cellular);
		input = RealTimeConsoleInput(&terminal, ConsoleInputFlags.allInputEvents);
		//init vars
		widgetSize.height = terminal.height;
		widgetSize.width = terminal.width;
		widgetCaption = caption;
		//set caption
		terminal.setTitle(widgetCaption);
		//create display matrix
		termDisplay = new Matrix(widgetSize.width, widgetSize.height, emptySpace);
	}
	~this(){
		terminal.clear;
		delete termDisplay;
	}

	///Use this to update teriminal, returns true if at least 1 widget was updated, don't call update directly on terminal
	bool updateDisplay(){
		termDisplay.clear(emptySpace);
		bool r = update(termDisplay);
		if (r){
			termDisplay.flushToTerminal(&this);
		}
		return r;
	}

	void run(){
		InputEvent event;
		isRunning = true;
		//draw the whole thing
		recalculateWidgetsSize;
		updateDisplay();
		while (isRunning){
			event = input.nextEvent;
			//check event type
			if (event.type == event.Type.KeyboardEvent){
				KeyPress kPress;
				kPress.key = event.get!(event.Type.KeyboardEvent).which;
				this.onKeyPress(kPress);
				updateDisplay;
			}else if (event.type == event.Type.MouseEvent){
				MouseEvent mEvent = event.get!(event.Type.MouseEvent);
				MouseClick mPos;
				mPos.x = mEvent.x;
				mPos.y = mEvent.y;
				switch (mEvent.buttons){
					case MouseEvent.Button.Left:
						mPos.mouseButton = mPos.Button.Left;
						break;
					case MouseEvent.Button.Right:
						mPos.mouseButton = mPos.Button.Right;
						break;
					case MouseEvent.Button.ScrollUp:
						mPos.mouseButton = mPos.Button.ScrollUp;
						break;
					case MouseEvent.Button.ScrollDown:
						mPos.mouseButton = mPos.Button.ScrollDown;
						break;
					default:
						continue;
				}
				this.onClick(mPos);
				updateDisplay;
			}else if (event.type == event.Type.SizeChangedEvent){
				//change matrix size
				termDisplay.changeSize(cast(uinteger)terminal.width, cast(uinteger)terminal.height, emptySpace);
				//update self size
				terminal.updateSize;
				widgetSize.height = terminal.height;
				widgetSize.width = terminal.width;
				//call size change on all widgets
				recalculateWidgetsSize;
				updateDisplay;
			}else if (event.type == event.Type.UserInterruptionEvent){
				//die here
				terminal.clear;
				isRunning = false;
				break;
			}
		}
	}

	void terminate(){
		isRunning = false;
	}

	//override write properties
	override @property Size size(Size newSize){
		//don't let anything modify the size
		return widgetSize;
	}
	override @property Position position(Position newPosition){
		return widgetPosition;
	}

	//functions below are used by Matrix.flushToTerminal
	void flush(){
		terminal.flush;
	}
	void clear(){
		terminal.clear;
	}
	void setColors(RGBColor textColor, RGBColor bgColor){
		terminal.setTrueColor(textColor, bgColor);
	}
	void moveTo(int x, int y){
		terminal.moveTo(x, y);
	}
	void writeChars(char[] c){
		terminal.write(c);
	}
	void writeChars(char c){
		terminal.write(c);
	}
}

///Theme class
class QTheme{
private:
	RGBColor[string][string] colors;//ind0 = widgetName, ind1 = color; if ind0 == null, ind0 = forAllWidgets
	RGBColor[string] globalColors;//contains colors for widgets without color
public:
	this(string themeFile = null){
		if (themeFile != null){
			loadTheme(themeFile);
		}
	}
	///gets color, provided the widgetName, and which-color (like textColor).
	///if not found, returns a default color provided by theme. If that color
	///is also not found, throws exception
	RGBColor getColor(string widgetName, string which){
		if (!(widgetName in colors) || !(which in colors[widgetName])){
			if (which in globalColors){
				return globalColors[which];
			}else{
				throw new Exception("Color "~which~" not defined (for "~widgetName~')');
			}
		}else{
			return colors[widgetName][which];
		}
	}
	///gets all colors for a  widget. does not return default-colors for theme
	RGBColor[string] getColors(string widgetName){
		if (!(widgetName in colors)){
			throw new Exception("Widget "~widgetName~" not defined");
		}else{
			return colors[widgetName];
		}
	}
	///sets color for a widget
	void setColor(string widgetName, string which, RGBColor color){
		colors[widgetName][which] = color;
	}
	///sets a color for widgets that are not defined
	void setColor(string which, RGBColor color){
		globalColors[which] = color;
	}
	///sets all colors for a widget
	void setColors(string widgetName, RGBColor[string] widgetColors){
		colors[widgetName] = widgetColors;
	}
	///Saves current theme to a file, returns false on error
	bool saveTheme(string filename){
		bool r = true;
		try{
			File f = File(filename, "w");
			foreach(widgetName; colors.keys){
				foreach(colorName; colors[widgetName].keys){
					f.write(widgetName,' ',colorName,' ',colorToHex(colors[widgetName][colorName]),'\n');
				}
			}
			foreach(colorName; globalColors.keys){
				f.write("* ",colorName,' ',colorToHex(globalColors[colorName]),'\n');
			}
			f.close;
		}catch(Exception e){
			r = false;
		}
		return r;
	}
	///Loads a theme from file, returns false on error
	bool loadTheme(string filename){
		bool r = true;
		try{
			string[] fcontents = fileToArray(filename);
			string widgetName, colorName, colorCode, line;
			uinteger lEnd;
			for (uinteger lno = 0; lno < fcontents.length; lno++){
				line = fcontents[lno];
				uinteger readFrom = 0;
				lEnd = line.length - 1;
				for (uinteger i = 0; i < line.length; i++){
					if (line[i] == ' ' || i == lEnd){
						if (widgetName == null){
							widgetName = line[readFrom .. i];
						}
						if (colorName == null){
							colorName = line[readFrom .. i];
						}
						if (colorCode == null){
							colorCode = line[readFrom .. i];
						}
						readFrom = i+1;
					}
				}
				//add color, if any
				if (widgetName && colorName && colorCode){
					if (widgetName == "*"){
						globalColors[colorName] = hexToColor(colorCode);
					}else{
						colors[widgetName][colorName] = hexToColor(colorCode);
					}
					//clear name ...
					widgetName, colorName, colorCode = null;
				}
			}
		}catch(Exception e){
			r = false;
		}
		return r;
	}

	///checks if theme has colors for a widget
	bool hasWidget(string widgetName){
		if (widgetName in colors){
			return true;
		}else{
			return false;
		}
	}
	///checks if theme has a color for a widget
	bool hasColor(string widgetName, string colorName){
		if (widgetName in colors){
			if (colorName in colors[widgetName]){
				return true;
			}else{
				return false;
			}
		}else{
			return false;
		}
	}
	///checks if theme has a color
	bool hasColor(string colorName){
		if (colorName in globalColors){
			return true;
		}else{
			return false;
		}
	}
}

//misc functions:
///Center-aligns text, returns that in an char[] with width as length
char[] centerAlignText(char[] text, uinteger width, char fill = ' '){
	char[] r;
	if (text.length < width){
		r.length = width;
		uinteger offset = (width - text.length)/2;
		r[0 .. offset] = fill;
		r[offset .. offset+text.length][] = text;
		r[offset+text.length .. r.length] = fill;
	}else{
		r = text[0 .. width];
	}
	return r;
}

///Can be used to calculate percentage->raw
uinteger ratioToRaw(uinteger selectedRatio, uinteger ratioTotal, uinteger total){
	uinteger r;
	r = cast(uinteger)((cast(float)selectedRatio/cast(float)ratioTotal)*total);
	return r;
}

///Converts hex color code to RGBColor
RGBColor hexToColor(string hex){
	RGBColor r;
	r.r = cast(ubyte)hexToDen(hex[0..2]);
	r.g = cast(ubyte)hexToDen(hex[2..4]);
	r.b = cast(ubyte)hexToDen(hex[4..6]);
	return r;
}

///Converts RGBColor to hex color code
string colorToHex(RGBColor col){
	char[] r;
	char[] code;
	r.length = 6;
	r[0 .. 6] = '0';
	code = cast(char[])denToHex(col.r);
	r[2 - code.length .. 2] = code;
	code = cast(char[])denToHex(col.g);
	r[4 - code.length .. 4] = code;
	code = cast(char[])denToHex(col.b);
	r[6 - code.length .. 6] = code;
	return cast(string)r;
}