module SessionManager;

import core.runtime;
import core.thread;
import std.algorithm : min, max;
import std.conv;
import std.math;
import std.range;
import std.string;
import std.stdio;
import std.utf;

auto toUTF16z(S)(S s) {
    return toUTFz!(const(wchar)*)(s);
}

pragma(lib, "gdi32.lib");
import core.sys.windows.windef;
import core.sys.windows.winuser;
import core.sys.windows.wingdi;
import core.sys.windows.winbase;

import execute;
import std.conv;

enum SM_FILE_NEW = 1;
enum SM_FILE_OPEN = 2;
enum SM_FILE_SAVE = 3;
enum SM_FILE_QUIT = 4;

enum SM_FONT_CONSOLAS = 11;
enum SM_FONT_COURIER = 12;
enum SM_FONT_LIBERATION = 13;
enum SM_FONT_LUCIDAS = 14;

enum SM_SIZE_10 = 110;
enum SM_SIZE_12 = 112;
enum SM_SIZE_14 = 114;
enum SM_SIZE_16 = 116;
enum SM_SIZE_18 = 118;
enum SM_SIZE_20 = 120;

enum SM_LANG_PLURAL = 42;
enum SM_LANG_J = 40;
enum SM_LANG_K = 41;

string appName = "SessionManager";
string FONT_NAME = "Consolas";

extern(Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow) {
    int result;

    try {
        Runtime.initialize();
        result = myWinMain(hInstance, hPrevInstance, lpCmdLine, iCmdShow);
        Runtime.terminate();
    }
    catch(Throwable o) {
        MessageBox(null, o.toString().toUTF16z, "Error", MB_OK | MB_ICONEXCLAMATION);
        result = 0;
    }

    return result;
}

int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow) {
    
    HWND hwnd;
	HMENU hMenu;
    MSG  msg;
    WNDCLASS wndclass;

    wndclass.style         = CS_HREDRAW | CS_VREDRAW;
    wndclass.lpfnWndProc   = &WndProc;
    wndclass.cbClsExtra    = 0;
    wndclass.cbWndExtra    = 0;
    wndclass.hInstance     = hInstance;
    wndclass.hIcon         = LoadIcon(NULL, IDI_APPLICATION);
    wndclass.hCursor       = LoadCursor(NULL, IDC_ARROW);
    wndclass.hbrBackground = cast(HBRUSH)GetStockObject(WHITE_BRUSH);
    wndclass.lpszMenuName  = NULL;
    wndclass.lpszClassName = appName.toUTF16z;

    if (!RegisterClass(&wndclass)) {
        MessageBox(NULL, "This program requires Windows NT!", appName.toUTF16z, MB_ICONERROR);
        return 0;
    }

    hwnd = CreateWindow(appName.toUTF16z,              // window class name
                        "Session Manager",             // window caption
                        WS_OVERLAPPEDWINDOW,           // window style
                        CW_USEDEFAULT,                 // initial x position
                        CW_USEDEFAULT,                 // initial y position
                        CW_USEDEFAULT,                 // initial x size
                        CW_USEDEFAULT,                 // initial y size
                        NULL,                          // parent window handle
                        NULL,                          // window menu handle
                        hInstance,                     // program instance handle
                        NULL);                         // creation parameters

	// hMenu = GetSystemMenu(hwnd, FALSE);
    // AppendMenu(hMenu, MF_SEPARATOR, 0,           NULL);
    // AppendMenu(hMenu, MF_STRING, SM_SYS_ABOUT,  "About...");
    // AppendMenu(hMenu, MF_STRING, SM_SYS_HELP,   "Help...");
    // AppendMenu(hMenu, MF_STRING, SM_SYS_REMOVE, "Remove Additions");

    ShowWindow(hwnd, iCmdShow);
    // UpdateWindow(hwnd);

    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return cast(int)msg.wParam;
}

extern(Windows)
LRESULT WndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) nothrow {
    scope (failure) assert(0);
    static DWORD dwCharSet = DEFAULT_CHARSET;
    static int cxChar, cyChar, cxClient, cyClient, cxBuffer, cyBuffer, xCaret, yCaret;
    static wchar[][] textBuffer;
	
    HDC hdc;
    int x;
    PAINTSTRUCT ps;
    TEXTMETRIC  tm;

    switch (message) {

		default:
			break;

        case WM_INPUTLANGCHANGE: {
			dwCharSet = cast(int)wParam;
			goto case WM_CREATE;
		}

        case WM_CREATE: {
			hdc = GetDC(hwnd);
			scope(exit) ReleaseDC(hwnd, hdc);

			SelectObject(hdc, CreateFont(0, 0, 0, 0, 0, 0, 0, 0, dwCharSet, 0, 0, 0, FIXED_PITCH, FONT_NAME.toUTF16z));
			scope(exit) DeleteObject(SelectObject(hdc, GetStockObject(SYSTEM_FONT)));

			GetTextMetrics(hdc, &tm);
			cxChar = tm.tmAveCharWidth;
			cyChar = tm.tmHeight;

			AddMenus(hwnd);

			goto case WM_SIZE;
		}

        case WM_SIZE: {
			// obtain window size in pixels
			if (message == WM_SIZE) {
				cxClient = LOWORD(lParam);
				cyClient = HIWORD(lParam);
			}

			// calculate window size in characters
			cxBuffer = max(1, cxClient / cxChar);
			cyBuffer = max(1, cyClient / cyChar);

			textBuffer = new wchar[][](cyBuffer, cxBuffer);
			foreach (ref wchar[] line; textBuffer) { line[] = ' '; }

			// set caret to upper left corner
			xCaret = yCaret = 0;
			if (hwnd == GetFocus()) { SetCaretPos(xCaret * cxChar, yCaret * cyChar); }
			InvalidateRect(hwnd, NULL, TRUE);
			return 0;
		}

        case WM_SETFOCUS: {
			CreateCaret(hwnd, NULL, cxChar, cyChar);
			SetCaretPos(xCaret * cxChar, yCaret * cyChar);
			ShowCaret(hwnd);
			return 0;
		}

        case WM_KILLFOCUS: {
			HideCaret(hwnd);
			DestroyCaret();
			return 0;
		}

        case WM_KEYDOWN: {
			switch (wParam) {
				case VK_HOME:
					xCaret = 0;
					break;

				case VK_END:
					xCaret = cxBuffer - 1;
					break;

				case VK_PRIOR:
					yCaret = 0;
					break;

				case VK_NEXT:
					yCaret = cyBuffer - 1;
					break;

				case VK_LEFT:
					xCaret = max(xCaret - 1, 0);
					break;

				case VK_RIGHT:
					xCaret = min(xCaret + 1, cxBuffer - 1);
					break;

				case VK_UP:
					yCaret = max(yCaret - 1, 0);
					break;

				case VK_DOWN:
					yCaret = min(yCaret + 1, cyBuffer - 1);
					break;

				case VK_DELETE: {
					textBuffer[yCaret] = textBuffer[yCaret][1..$] ~ ' ';
					HideCaret(hwnd);

					hdc = GetDC(hwnd);
					scope(exit) ReleaseDC(hwnd, hdc);

					SelectObject(hdc, CreateFont(0, 0, 0, 0, 0, 0, 0, 0, dwCharSet, 0, 0, 0, FIXED_PITCH, FONT_NAME.toUTF16z));
					scope(exit) DeleteObject(SelectObject(hdc, GetStockObject(SYSTEM_FONT)));

					TextOut(hdc, xCaret * cxChar, yCaret * cyChar, &textBuffer[yCaret][xCaret], cxBuffer - xCaret);
					ShowCaret(hwnd);
					break;
				}

				default:
			}

			SetCaretPos(xCaret * cxChar, yCaret * cyChar);
			return 0;
		}

        case WM_CHAR: {
			// lParam stores the repeat count of a character
			foreach (i; 0 .. cast(int)LOWORD(lParam)) {
				switch (wParam) {
					case '\b': {
						if (xCaret > 0) {
							xCaret--;
							SendMessage(hwnd, WM_KEYDOWN, VK_DELETE, 1);
						}
						break;
					}

					case '\t': {
						do { SendMessage(hwnd, WM_CHAR, ' ', 1); }
						while (xCaret % 4 != 0);
						break;
					}

					case '\n': {
						if (++yCaret == cyBuffer) { 
							yCaret = 0; 
						}
						break;
					}

					case '\r': {
						xCaret = 0;
						string txt = exec(to!string(textBuffer[yCaret]));
						if (++yCaret == cyBuffer) { 
							yCaret = 0; 
						}
						for (int j = 0; j < textBuffer[yCaret].length; j++) { textBuffer[yCaret][j] = ' '; }
						for (int j = 0; j < txt.length; j++) { textBuffer[yCaret][j] = txt[j]; }

						// repaint the one line for now
						HideCaret(hwnd);

						hdc = GetDC(hwnd);
						scope(exit) ReleaseDC(hwnd, hdc);

						SelectObject(hdc, CreateFont(0, 0, 0, 0, 0, 0, 0, 0, dwCharSet, 0, 0, 0, FIXED_PITCH, FONT_NAME.toUTF16z));
						scope(exit) DeleteObject(SelectObject(hdc, GetStockObject(SYSTEM_FONT)));

						TextOut(hdc, xCaret * cxChar, yCaret * cyChar, &textBuffer[yCaret][0], cast(int)txt.length);
						ShowCaret(hwnd);

						// back to earth
						if (++yCaret == cyBuffer) { 
							yCaret = 0; 
						}
						break;
					}

					case '\x1B': { // escape
						foreach (ref wchar[] line; textBuffer) { line[] = ' '; }
						xCaret = yCaret = 0;
						InvalidateRect(hwnd, NULL, FALSE);
						break;
					}

					default: {  // other chars
							
						textBuffer[yCaret][xCaret] = cast(char)wParam;
						HideCaret(hwnd);

						hdc = GetDC(hwnd);
						scope(exit) ReleaseDC(hwnd, hdc);

						SelectObject(hdc, CreateFont(0, 0, 0, 0, 0, 0, 0, 0, dwCharSet, 0, 0, 0, FIXED_PITCH, FONT_NAME.toUTF16z));
						scope(exit) DeleteObject(SelectObject(hdc, GetStockObject(SYSTEM_FONT)));

						TextOut(hdc, xCaret * cxChar, yCaret * cyChar, &textBuffer[yCaret][xCaret], 1);

						ShowCaret(hwnd);

						if (++xCaret == cxBuffer) {
							xCaret = 0;
							if (++yCaret == cyBuffer) { 
								yCaret = 0; 
							}
						}
						break;
					}
				}
			}

			SetCaretPos(xCaret * cxChar, yCaret * cyChar);
			return 0;
		}

        case WM_PAINT: {
			hdc = BeginPaint(hwnd, &ps);
			scope(exit) EndPaint(hwnd, &ps);

			SelectObject(hdc, CreateFont(0, 0, 0, 0, 0, 0, 0, 0, dwCharSet, 0, 0, 0, FIXED_PITCH, FONT_NAME.toUTF16z));
			scope(exit) DeleteObject(SelectObject(hdc, GetStockObject(SYSTEM_FONT)));

			foreach (y; 0 .. cyBuffer) {
				TextOut(hdc, 0, y * cyChar, textBuffer[y].ptr, cxBuffer);
			}

			return 0;
		}

        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;

        case WM_COMMAND: {
			switch (LOWORD(wParam)) {
				case SM_FILE_OPEN:
				case SM_FILE_SAVE:
					core.sys.windows.winuser.MessageBox(NULL, "A Poor-Person's Menu Program\n(c) Charles Petzold, 1998".toUTF16z, appName.toUTF16z, 0);
					return 0;

				case SM_FILE_QUIT:
				case SM_FILE_NEW:
					core.sys.windows.winuser.MessageBox(hwnd, "Help not yet implemented!".toUTF16z, appName.toUTF16z, MB_OK | MB_ICONEXCLAMATION);
					return 0;

				default:
			}
		}
    }

    return DefWindowProc(hwnd, message, wParam, lParam);
}

void AddMenus(HWND hwnd) nothrow {

    HMENU hMenubar = CreateMenu;
    HMENU hMenu = CreateMenu;
	HMENU hMenu2 = CreateMenu;
	HMENU hMenu3 = CreateMenu;
	HMENU hMenu4 = CreateMenu;

    AppendMenu(hMenu, MF_STRING, SM_FILE_NEW, "&New");
    AppendMenu(hMenu, MF_STRING, SM_FILE_OPEN, "&Open");
	AppendMenu(hMenu, MF_STRING, SM_FILE_SAVE, "&Save");
    AppendMenu(hMenu, MF_SEPARATOR, 0, NULL);
    AppendMenu(hMenu, MF_STRING, SM_FILE_QUIT, "&Quit");

    AppendMenu(hMenubar, MF_POPUP, cast(UINT_PTR) hMenu, "&File");

	AppendMenu(hMenu2, MF_STRING, SM_FONT_CONSOLAS, "&Consolas");
    AppendMenu(hMenu2, MF_STRING, SM_FONT_COURIER, "&Courier New");
    AppendMenu(hMenu2, MF_STRING, SM_FONT_LIBERATION, "&Liberation Mono");
	AppendMenu(hMenu2, MF_STRING, SM_FONT_LUCIDAS, "&Lucidas Console");

    AppendMenu(hMenubar, MF_POPUP, cast(UINT_PTR) hMenu2, "&Font");

	AppendMenu(hMenu3, MF_STRING, SM_SIZE_10, "10");
    AppendMenu(hMenu3, MF_STRING, SM_SIZE_12, "12");
    AppendMenu(hMenu3, MF_STRING, SM_SIZE_14, "14");
	AppendMenu(hMenu3, MF_STRING, SM_SIZE_16, "16");
	AppendMenu(hMenu3, MF_STRING, SM_SIZE_18, "18");
	AppendMenu(hMenu3, MF_STRING, SM_SIZE_20, "20");

	AppendMenu(hMenubar, MF_POPUP, cast(UINT_PTR) hMenu3, "&Size");

	AppendMenu(hMenu4, MF_STRING, SM_LANG_PLURAL, "&Plural");
    AppendMenu(hMenu4, MF_STRING, SM_LANG_J, "&J");
    AppendMenu(hMenu4, MF_STRING, SM_LANG_K, "&K");

    AppendMenu(hMenubar, MF_POPUP, cast(UINT_PTR) hMenu4, "&Language");

    SetMenu(hwnd, hMenubar);
}
