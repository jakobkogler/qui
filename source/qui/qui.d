/++
	This module contains most of the functions you'll need.
	All the 'base' classes, like QWidget are defined in this.
+/
module qui.qui;

import arsd.terminal;
import std.stdio;
import utils.baseconv;
import utils.lists;
import utils.misc;

///Mouse Click, or Ms Wheel scroll event
///
///The mouseEvent function is called with this.
struct MouseClick{
	///Types of buttons
	enum Button{
		Left,/// Left mouse button
		ScrollUp,/// MS wheel was scrolled up
		ScrollDown,/// MS wheel was scrolled down
		Right,/// Right mouse button was pressed
	}
	///Stores which button was pressed
	Button mouseButton;
	/// the x-axis of mouse cursor, 0 means left-most
	uinteger x;
	/// the y-axis of mouse cursor, 0 means top-most
	uinteger y;
}

///Key press event, keyboardEvent function is called with this
///
///A note: backspace (`\b`) and enter (`\n`) are not included in KeyPress.NonCharKey
struct KeyPress{
	dchar key;/// stores which key was pressed
	
	/// Returns true if the key was a character.
	/// 
	/// A note: Enter/Return ('\n') is not included in KeyPress.NonCharKey
	bool isChar(){
		return !(key >= NonCharKey.min && key <= NonCharKey.max);
	}
	/// Types of non-character keys
	enum NonCharKey{
		Escape = 0x1b + 0xF0000,
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

/// A 24 bit, RGB, color
/// 
/// `r` represents amount of red, `g` is green, and `b` is blue.
/// the `a` is ignored
alias RGBColor = RGB;

/// Used to store position for widgets
struct Position{
	uinteger x, y;
}

/// To store size for widgets
/// 
/// zero in min/max means no limit
struct Size{
	private{
		uinteger w, h;
		bool hasChanged; /// specifies if has been changed.
	}
	/// returns whether the size was changed since the last time this property was read
	@property bool sizeChanged(){
		if (hasChanged){
			hasChanged = false;
			return true;
		}else{
			return false;
		}
	}
	/// width
	@property uinteger width(){
		return w;
	}
	/// width
	@property uinteger width(uinteger newWidth){
		if (minWidth > 0 && newWidth < minWidth){
			return w = minWidth;
		}else if (maxWidth > 0 && newWidth > maxWidth){
			return w = maxWidth;
		}else{
			return w = newWidth;
		}
	}
	/// height
	@property uinteger height(){
		return h;
	}
	/// height
	@property uinteger height(uinteger newHeight){
		if (minHeight > 0 && newHeight < minHeight){
			return h = minHeight;
		}else if (maxHeight > 0 && newHeight > maxHeight){
			return h = maxHeight;
		}else{
			return h = newHeight;
		}
	}
	/// minimun width & height. These are "applied" automatically when setting value using `width` or `height`
	uinteger minWidth = 0, minHeight = 0;
	/// maximum width & height. These are "applied" automatically when setting value using `width` or `height`
	uinteger maxWidth = 0, maxHeight = 0;
}

/// mouseEvent function
alias MouseEventFuction = void delegate(MouseClick);
///keyboardEvent function
alias KeyboardEventFunction = void delegate(KeyPress);


/// Base class for all widgets, including layouts and QTerminal
///
/// Use this as parent-class for new widgets
abstract class QWidget{
protected:
	///specifies position of this widget
	Position widgetPosition;
	///size of this widget
	Size widgetSize;
	///caption of this widget, it's up to the widget how to use this, TextLabelWidget shows this as the text
	string widgetCaption;
	///whether this widget should be drawn or not
	bool widgetShow = true;
	///to specify if this widget needs to be updated or not, mark this as true when the widget has changed
	bool needsUpdate = true;
	/// specifies that how much height (in horizontal layout) or width (in vertical) is given to this widget.
	/// The ratio of all widgets is added up and height/width for each widget is then calculated using this
	uinteger widgetSizeRatio = 1;
	
	/// Called by widget when a redraw is needed, when no redraw is scheduled
	/// 
	/// In other words: call this function using (or it'll cause a segfault):
	/// ```
	/// if (forceUpdate !is null){
	/// 	forceUpdate();
	/// }
	/// ``` 
	/// when an update is needed, and it's not sure if an update will be called.
	/// If an update is already ongoing, this function will return false, or scheduled
	bool delegate() forceUpdate;
	
	/// Called by widgets (usually keyboard-input-taking) to position the cursor
	/// 
	/// It can only be called if the widget is active (i.e selected), in non-active widgets, it is null;
	/// The position is relative to the (0, 0) on terminal
	void delegate(uinteger x, uinteger y) cursorPos;
	
	/// custom mouse event, if not null, it should be called before doing anything else in mouseEvent.
	/// 
	/// Like:
	/// ```
	/// override void mouseEvent(MouseClick mouse){
	/// 	super.mouseEvent(mouse);
	/// 	// rest of the code for mouse event here
	/// }
	/// ```
	MouseEventFuction customMouseEvent;
	
	/// custom keyboard event, if not null, it should be called before doing anything else in keyboardEvent.
	/// 
	/// Like:
	/// ```
	/// override void keyboardEvent(KeyPress key){
	/// 	super.keyboardEvent(key);
	/// 	// rest of the code for keyboard event here
	/// }
	/// ```
	KeyboardEventFunction customKeyboardEvent;
public:
	/// Called by owner when mouse is clicked with cursor on this widget.
	/// 
	/// Must be inherited like:
	/// ```
	/// 	override void mouseEvent(MouseClick mouse){
	/// 		super.mouseEvent(mouse);
	/// 		// code to handle this event here
	/// 	}
	/// ```
	/// `forceUpdate` is not required after this. if `forceUpdate` is called in this, it will have no effect
	void mouseEvent(MouseClick mouse){
		if (customMouseEvent !is null){
			customMouseEvent(mouse);
		}
	}
	
	/// Called by owner when key is pressed and this widget is active.
	/// 
	/// Must be inherited like:
	/// ```
	/// 	override void keyboardEvent(KeyPress key){
	/// 		super.keyboardEvent(key);
	/// 		// code to handle this event here
	/// 	}
	/// ```
	/// `forceUpdate` is not required after this. if `forceUpdate` is called in this, it will have no effect
	void keyboardEvent(KeyPress key){
		if (customKeyboardEvent !is null){
			customKeyboardEvent(key);
		}
	}

	/// called by `QLayout` when the widget is resized.
	void resize(){
		needsUpdate = true;
	}
	
	/// Called by owner to update.
	/// 
	/// It must be inherited like:
	/// ```
	/// 	override bool update(Matrix display){
	/// 		if (super.update(null)){
	/// 			// code to do the update here
	/// 		}	
	/// 	}
	/// ```
	/// Or size-changes wont make it resize
	/// 
	/// Return false if no need to update, and true if an update is required, and the new display in `display` Matrix
	bool update(Matrix display){
		needsUpdate = (this.size.sizeChanged ? true : needsUpdate);
		return needsUpdate;
	}
	
	//event properties
	/// use to change the custom mouse event
	@property MouseEventFuction onMouseEvent(MouseEventFuction func){
		return customMouseEvent = func;
	}
	/// use to change the custom keyboard event
	@property KeyboardEventFunction onKeyboardEvent(KeyboardEventFunction func){
		return customKeyboardEvent = func;
	}
	
	
	//properties:
	
	/// caption of the widget. getter
	@property string caption(){
		return widgetCaption;
	}
	/// caption of the widget. setter
	@property string caption(string newCaption){
		needsUpdate = true;
		widgetCaption = newCaption;
		if (forceUpdate !is null){
			forceUpdate();
		}
		return widgetCaption;
	}
	
	/// position of the widget. getter
	@property ref Position position(){
		return widgetPosition;
	}
	/// position of the widget. setter
	@property ref Position position(Position newPosition){
		widgetPosition = newPosition;
		if (forceUpdate !is null){
			forceUpdate();
		}
		return widgetPosition;
	}
	
	/// size (width/height) of the widget. getter
	@property uinteger sizeRatio(){
		return widgetSizeRatio;
	}
	/// size (width/height) of the widget. setter
	@property uinteger sizeRatio(uinteger newRatio){
		needsUpdate = true;
		widgetSizeRatio = newRatio;
		if (forceUpdate !is null){
			forceUpdate();
		}
		return widgetSizeRatio;
	}
	
	/// visibility of the widget. getter
	@property bool visible(){
		return widgetShow;
	}
	/// visibility of the widget. setter
	@property bool visible(bool visibility){
		needsUpdate = true;
		widgetShow = visibility;
		if (forceUpdate !is null){
			forceUpdate();
		}
		return widgetShow;
	}
	
	/// called by owner to set the `forceUpdate` function, which is used to force an update immediately.
	@property bool delegate() onForceUpdate(bool delegate() newOnForceUpdate){
		return forceUpdate = newOnForceUpdate;
	}
	/// called by the owner to set the `cursorPos` function, which is used to position the cursor on the terminal.
	@property void delegate(uinteger, uinteger) onCursorPosition(void delegate(uinteger, uinteger) newOnCursorPos){
		return cursorPos = newOnCursorPos;
	}
	/// size of the widget. getter
	@property ref Size size(){
		return widgetSize;
	}
	/// size of the widget. setter
	@property ref Size size(Size newSize){
		return widgetSize = newSize;
	}
}

/// Layout type
enum LayoutDisplayType{
	Vertical,
	Horizontal,
}

///Used to place widgets in an order (i.e vertical or horizontal)
///
///The QTerminal is also a layout, basically.
///
///Name in theme: 'layout';
class QLayout : QWidget{
private:
	// array of all the widgets that have been added to this layout
	QWidget[] widgetList;
	// contains reference to the active widget, null if no active widget
	QWidget activeWidget;
	// stores the layout type, horizontal or vertical
	LayoutDisplayType layoutType;
	
	// background color
	RGBColor bgColor;
	// foreground color
	RGBColor textColor;
	// stores whether an update is in progress
	bool isUpdating = false;
	
	// recalculates the size of every widget inside layout
	void recalculateWidgetsSize(LayoutDisplayType T)(QWidget[] widgets, uinteger totalSpace, uinteger totalRatio){
		static if (T != LayoutDisplayType.Horizontal && T != LayoutDisplayType.Vertical){
			assert(false);
		}
		uinteger repeat;
		do{
			repeat = false;
			foreach(i, widget; widgets){
				if (widget.visible){
					// calculate width or height
					uinteger newSpace = ratioToRaw(widget.sizeRatio, totalRatio, totalSpace);
					uinteger calculatedSpace = newSpace;
					//apply size
					static if (T == LayoutDisplayType.Horizontal){
						widget.size.height = widgetSize.height;
						widget.size.width = newSpace;
						newSpace = widget.size.width;
					}else{
						widget.size.width = widgetSize.width;
						widget.size.height = newSpace;
						newSpace = widget.size.height;
					}
					// let the know it was resized, useful if the widget is a layout. This marks `needsUpdate` true in the widget
					widget.resize;
					if (newSpace != calculatedSpace){
						totalRatio -= widget.sizeRatio;
						totalSpace -= newSpace;
						widgets = widgets.dup.deleteElement(i);
						repeat = true;
						break;
					}
					// check if there's enough space to contain that widget
					if (newSpace > totalSpace){
						newSpace = 0;
						widget.visible = false;
					}
				}
			}
		} while (repeat);
	}
	/// calculates and assigns widgets positions based on their sizes
	void recalculateWidgetsPosition(LayoutDisplayType T)(QWidget[] widgets){
		static if (T != LayoutDisplayType.Horizontal && T != LayoutDisplayType.Vertical){
			assert(false);
		}
		uinteger previousSpace = (T == LayoutDisplayType.Horizontal ? widgetPosition.x : widgetPosition.y);
		uinteger fixedPoint = (T == LayoutDisplayType.Horizontal ? widgetPosition.y : widgetPosition.x);
		foreach(widget; widgets){
			if (widget.visible){
				static if (T == LayoutDisplayType.Horizontal){
					widget.position.y = widgetPosition.y;
					widget.position.x = previousSpace;
					previousSpace += widget.size.width;
				}else{
					widget.position.x = widgetPosition.x;
					widget.position.y = previousSpace;
					previousSpace += widget.size.height;
				}
			}
		}
	}
	
public:
	this(LayoutDisplayType type){
		layoutType = type;
		activeWidget = null;
	}
	
	/// adds (appends) a widget to the widgetList, and makes space for it
	/// 
	/// If there a widget is too large, it's marked as not visible
	void addWidget(QWidget widget){
		widget.onForceUpdate = forceUpdate;
		//add it to array
		widgetList.length++;
		widgetList[widgetList.length-1] = widget;
		//recalculate all widget's size to adjust
		resize();
	}
	/// adds (appends) widgets to the widgetList, and makes space for them
	/// 
	/// If there a widget is too large, it's marked as not visible
	void addWidget(QWidget[] widgets){
		foreach(widget; widgets){
			widget.onForceUpdate = forceUpdate;
		}
		// add to array
		widgetList ~= widgets.dup;
		//resize
		resize();
	}
	
	/// Recalculates size and position for all visible widgets
	/// If a widget is too large to fit in, it's visibility is marked false
	override void resize(){
		//disable update during size change, saves CPU and time
		isUpdating = true;
		uinteger ratioTotal;
		foreach(w; widgetList){
			if (w.visible()){
				ratioTotal += w.sizeRatio;
			}
		}
		if (layoutType == LayoutDisplayType.Horizontal){
			recalculateWidgetsSize!(LayoutDisplayType.Horizontal)(widgetList, widgetSize.width, ratioTotal);
			recalculateWidgetsPosition!(LayoutDisplayType.Horizontal)(widgetList);
		}else{
			recalculateWidgetsSize!(LayoutDisplayType.Vertical)(widgetList, widgetSize.height, ratioTotal);
			recalculateWidgetsPosition!(LayoutDisplayType.Vertical)(widgetList);
		}
		isUpdating = false;
	}
	
	override void mouseEvent(MouseClick mouse){
		super.mouseEvent(mouse);
		//remove access to cursor from previous active widget
		if (activeWidget){
			activeWidget.onCursorPosition = null;
		}
		foreach (widget; widgetList){
			if (widget.visible){
				Position p = widget.position;
				Size s = widget.size;
				//check x-axis
				if (mouse.x >= p.x && mouse.x < p.x + s.width){
					//check y-axis
					if (mouse.y >= p.y && mouse.y < p.y + s.height){
						//give access to cursor position
						widget.onCursorPosition = cursorPos;
						//call mouseEvent
						widget.mouseEvent(mouse);
						//mark this widget as active
						activeWidget = widget;
						break;
					}
				}
			}
		}
	}
	override void keyboardEvent(KeyPress key){
		super.keyboardEvent(key);
		//check active widget, call keyboardEvent
		if (activeWidget){
			activeWidget.keyboardEvent(key);
		}
	}
	override bool update(Matrix display){
		bool updated = false;
		//check if already updating, case yes, return false
		if (!isUpdating){
			isUpdating = true;
			//go through all widgets, check if they need update, update them
			Matrix wDisplay = new Matrix(1,1);
			foreach(widget; widgetList){
				if (widget.visible){
					wDisplay.changeSize(widget.size.width, widget.size.height);
					wDisplay.resetWritePosition();
					if (widget.update(wDisplay)){
						display.insert(wDisplay, widget.position.x, widget.position.y);
						updated = true;
					}
					wDisplay.clear();
				}
			}
			isUpdating = false;
		}else{
			return false;
		}
		return updated;
	}

	// override setOnForceUpdate to change it for all child widgets as well
	override @property bool delegate() onForceUpdate(bool delegate() newOnForceUpdate){
		// change it for all child widgets
		foreach(widget; widgetList){
			widget.onForceUpdate = newOnForceUpdate;
		}
		// change it for itself
		return super.onForceUpdate(newOnForceUpdate);
	}
}

/// A terminal (as the name says).
/// 
/// All widgets, receives events, runs UI loop...
/// 
/// Name in theme: 'terminal';
class QTerminal : QLayout{
private:
	Terminal terminal;
	RealTimeConsoleInput input;
	Matrix termDisplay;
	
	Position cursorPos;
	
	bool isRunning = false;
public:
	this(string caption = "QUI Text User Interface", LayoutDisplayType displayType = LayoutDisplayType.Vertical){
		super(displayType);
		//create terminal & input
		terminal = Terminal(ConsoleOutputType.cellular);
		input = RealTimeConsoleInput(&terminal, ConsoleInputFlags.allInputEvents);
		terminal.showCursor();
		//init vars
		widgetSize.height = terminal.height;
		widgetSize.width = terminal.width;
		widgetCaption = caption;
		//set caption
		terminal.setTitle(widgetCaption);
		//create display matrix
		termDisplay = new Matrix(widgetSize.width, widgetSize.height);
		termDisplay.setColors(textColor, bgColor);
	}
	~this(){
		terminal.clear;
		delete termDisplay;
	}
	
	override public void addWidget(QWidget widget){
		super.addWidget(widget);
		widget.onForceUpdate = &updateDisplay;
	}
	override public void addWidget(QWidget[] widgets){
		super.addWidget(widgets);
		foreach (widget; widgets){
			widget.onForceUpdate = &updateDisplay;
		}
	}
	
	override public void mouseEvent(MouseClick mouse) {
		super.mouseEvent(mouse);
		//remove access to cursor from previous active widget
		if (activeWidget){
			activeWidget.onCursorPosition = null;
		}
		foreach (widget; widgetList){
			if (widget.visible){
				Position p = widget.position;
				Size s = widget.size;
				//check x-axis
				if (mouse.x >= p.x && mouse.x < p.x + s.width){
					//check y-axis
					if (mouse.y >= p.y && mouse.y < p.y + s.height){
						//give access to cursor position
						widget.onCursorPosition = &setCursorPos;
						//call mouseEvent
						widget.mouseEvent(mouse);
						//mark this widget as active
						activeWidget = widget;
						break;
					}
				}
			}
		}
	}
	
	/// Use this instead of `update` to forcefully update the terminal
	/// 
	/// returns true if at least one widget was updated, false if nothing was updated
	bool updateDisplay(){
		if (isRunning && !isUpdating){
			bool r = update(termDisplay);
			if (r){
				terminal.moveTo(0, 0);
				termDisplay.flushToTerminal(this);
			}
			//set cursor position
			terminal.moveTo(cast(int)cursorPos.x, cast(int)cursorPos.y);
			terminal.showCursor();
			return r;
		}else{
			return false;
		}
	}
	
	/// starts the UI loop
	void run(){
		InputEvent event;
		isRunning = true;
		//resize all widgets
		resize();
		//draw the whole thing
		updateDisplay();
		while (isRunning){
			event = input.nextEvent;
			//check event type
			if (event.type == event.Type.KeyboardEvent){
				// prevent any updates during event, the update will be done at end
				isUpdating = true;
				KeyPress kPress;
				kPress.key = event.get!(event.Type.KeyboardEvent).which;
				this.keyboardEvent(kPress);
				// now it can update
				isUpdating = false;
				updateDisplay;
			}else if (event.type == event.Type.MouseEvent){
				// prevent any updates during event, the update will be done at end
				isUpdating = true;
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
				this.mouseEvent(mPos);
				// now it can update
				isUpdating = false;
				updateDisplay;
			}else if (event.type == event.Type.SizeChangedEvent){
				//change matrix size
				termDisplay.changeSize(cast(uinteger)terminal.width, cast(uinteger)terminal.height);
				termDisplay.setColors(textColor, bgColor);
				//update self size
				terminal.updateSize;
				widgetSize.height = terminal.height;
				widgetSize.width = terminal.width;
				this.clear;
				//call size change on all widgets
				resize();
				updateDisplay;
			}else if (event.type == event.Type.UserInterruptionEvent){
				//die here
				terminal.clear;
				isRunning = false;
				break;
			}
		}
		//in case an exception prevents it from being set to false before
		isRunning = false;
	}
	
	/// terminates the UI loop
	void terminate(){
		isRunning = false;
	}

	/// Called by active-widget to position the cursor
	void setCursorPos(uinteger x, uinteger y){
		cursorPos.x = x;
		cursorPos.y = y;
	}
	
	///returns true if UI loop is running
	@property bool running(){
		return isRunning;
	}
	
	//functions below are used by Matrix.flushToTerminal
	///flush changes to terminal, called by Matrix
	void flush(){
		terminal.flush;
	}
	///clear terminal, called before writing, called by Matrix
	void clear(){
		terminal.clear;
	}
	///change colors, called by Matrix
	void setColors(RGBColor textColor, RGBColor bgColor){
		terminal.setTrueColor(textColor, bgColor);
	}
	///move write-cursor to a position, called by Matrix
	void moveTo(int x, int y){
		terminal.moveTo(x, y);
	}
	///write chars to terminal, called by Matrix
	void writeChars(char[] c){
		terminal.write(c);
	}
	///write char to terminal, called by Matrix
	void writeChars(char c){
		terminal.write(c);
	}
}

/// Used to manage the characters on the terminal
class Matrix{
private:
	struct Display{
		uinteger x, y;
		RGBColor bgColor, textColor;
		char[] content;
	}
	//matrix size
	uinteger matrixHeight, matrixWidth;
	//next write position
	uinteger xPosition, yPosition;
	
	LinkedList!Display toUpdate;
	
public:
	this(uinteger width, uinteger height){
		toUpdate = new LinkedList!Display;
		//set size
		matrixHeight = 1;
		matrixWidth = 1;
		if (width > 1){
			matrixWidth = width;
		}
		if (height > 1){
			matrixHeight = height;
		}
		//set write positions
		xPosition = 0;
		yPosition = 0;
	}
	~this(){
		toUpdate.destroy;
	}
	///Clear the matrix, resets write position
	void clear(){
		toUpdate.clear;
		resetWritePosition();
	}
	/// clears the matrix, resets write position, and changes matrix size
	void changeSize(uinteger width, uinteger height){
		clear;
		matrixWidth = width;
		matrixHeight = height;
		if (matrixWidth == 0){
			matrixWidth = 1;
		}
		if (matrixHeight == 0){
			matrixHeight = 1;
		}
	}
	///sets write position to (0, 0)
	void resetWritePosition(){
		xPosition = 0;
		yPosition = 0;
	}
	/// To write to terminal
	void write(char[] c, RGBColor textColor, RGBColor bgColor){
		//get available cells
		uinteger cells = (matrixHeight - yPosition) * matrixWidth;// first get the whole area
		cells -= xPosition;//subtract partial-lines
		if (c.length > cells){
			c = c[0 .. cells];
		}
		if (c.length > 0){
			uinteger toAdd = xPosition + (yPosition * matrixWidth);
			Display disp;
			disp.bgColor = bgColor;
			disp.textColor = textColor;
			for (uinteger i = 0, readFrom = 0, end = c.length+1; i < end; i ++){
				if ((i+toAdd)%matrixWidth == 0 || i == c.length){
					//line ended, append it
					disp.x = (readFrom+toAdd)%matrixWidth;
					disp.y = (readFrom+toAdd)/matrixWidth;
					disp.content = c[readFrom .. i].dup;
					if (disp.content != null){
						toUpdate.append(disp);
						readFrom = i;
					}
				}
			}
			// update x and y positions
			xPosition = (c.length+toAdd)%matrixWidth;
			yPosition = (c.length+toAdd)/matrixWidth;
		}
	}
	/// Changes the matrix's colors. Must be called before any writing has taken place
	void setColors(RGBColor textColor, RGBColor bgColor){
		toUpdate.clear;// because it's contents are going to be overwritten, so why bother waste time writing them?
		Display disp;
		disp.bgColor = bgColor;
		disp.textColor = textColor;
		disp.x = 0;
		disp.y = 0;
		disp.content.length = matrixWidth;
		disp.content[] = ' ';
		// loop and set colors
		for (uinteger i = 0; i < matrixHeight; i ++){
			toUpdate.append(disp);
			disp.y ++;
		}
	}
	///move to a different position to write
	void moveTo(uinteger x, uinteger y){
		if (x < matrixWidth && y < matrixHeight){
			xPosition = x;
			yPosition = y;
		}
	}
	///returns number of rows/lines in matrix
	@property uinteger rowCount(){
		return matrixHeight;
	}
	///returns number of columns in matrix
	@property uinteger colCount(){
		return matrixWidth;
	}
	///returns the point ox x-axis where next write will start from
	@property Position writePos(){
		Position r;
		r.x = xPosition;
		r.y = yPosition;
		return r;
	}
	/// Returns in an array, list of all changes that have to be drawn on terminal. Used by `Matrix.insert` to copy contents
	Display[] toArray(){
		return toUpdate.toArray;
	}
	///insert a matrix into this one at a position
	void insert(Matrix toInsert, uinteger x, uinteger y){
		Display[] newMatrix = toInsert.toArray.dup;
		// go through the new Displays and increae their x and y, and append them
		foreach (disp; newMatrix){
			disp.y += y;
			disp.x += x;
			
			toUpdate.append(disp);
		}
	}
	///Write contents of matrix to a QTerminal
	void flushToTerminal(QTerminal terminal){
		if (toUpdate.count > 0){
			toUpdate.resetRead;
			Display* disp = toUpdate.read;
			do{
				terminal.moveTo(cast(int)(*disp).x, cast(int)(*disp).y);
				terminal.setColors((*disp).textColor, (*disp).bgColor);
				terminal.writeChars((*disp).content);
				
				disp = toUpdate.read;
			}while (disp !is null);
			terminal.flush();
			
			toUpdate.clear;
		}
	}
}

//misc functions:
///Center-aligns text, returns that in an char[] with width as length. The empty part filled with ' '
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
///
unittest{
	assert((cast(char[])"qwr").centerAlignText(7) == "  qwr  ");
}

///used to calculate height/width using sizeRation
uinteger ratioToRaw(uinteger selectedRatio, uinteger ratioTotal, uinteger total){
	uinteger r;
	r = cast(uinteger)((cast(float)selectedRatio/cast(float)ratioTotal)*total);
	return r;
}

///Converts hex color code to RGBColor
RGBColor hexToColor(string hex){
	RGBColor r;
	uinteger den = hexToDenary(hex);
	//min val for red in denary = 65536
	//min val for green in denary = 256
	//the remaining value is blue
	if (den >= 65536){
		r.r = cast(ubyte)((den / 65536));
		den -= r.r*65536;
	}
	if (den >= 256){
		r.g = cast(ubyte)((den / 256));
		den -= r.g*256;
	}
	r.b = cast(ubyte)den;
	return r;
}
///
unittest{
	RGBColor c;
	c.r = 10;
	c.g = 15;
	c.b = 0;
	assert("0A0F00".hexToColor == c);
}

///Converts RGBColor to hex color code
string colorToHex(RGBColor col){
	uinteger den;
	den = col.b;
	den += col.g*256;
	den += col.r*65536;
	return denaryToHex(den);
}
///
unittest{
	RGBColor c;
	c.r = 10;
	c.g = 8;
	c.b = 12;
	assert(c.colorToHex == "A080C");
}
