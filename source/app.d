import std.stdio : write, writeln, readln;
import std.string : fromStringz;

import bindbc.sdl;
import bindbcLoader = bindbc.loader.sharedlib;
import serialport : SerialPortNonBlk;

// SDL docs: https://wiki.libsdl.org/
int createSDLApp()
{
    auto sdlLoadResult = loadSDL();
    if (sdlLoadResult != sdlSupport)
    {
        writeln("Failed to load SDL.");

        foreach (error; bindbcLoader.errors)
        {
            writeln("Loader error: ", fromStringz(error.error), ": ",
                    fromStringz(error.message));
        }

        return 1;
    }

    if (SDL_Init(SDL_INIT_VIDEO) < 0)
    {
        writeln("Failed to init SDL: ", SDL_GetError());
        return 1;
    }

    const auto windowWidth = 1280;
    const auto windowHeight = 780;

    auto window = SDL_CreateWindow(
        "Window", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
        windowWidth, windowHeight, 0);
    if (!window)
    {
        writeln("Could not create window: ", SDL_GetError());
        return 1;
    }

    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "linear");

    auto renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

    SDL_Vertex[3] vertices = [
        SDL_Vertex(SDL_FPoint(windowWidth / 2, 0),
                   SDL_Color(255, 0, 0, 255),
                   SDL_FPoint(0)),
        SDL_Vertex(SDL_FPoint(0, windowHeight),
                   SDL_Color(0, 0, 255, 255),
                   SDL_FPoint(0)),
        SDL_Vertex(SDL_FPoint(windowWidth, windowHeight),
                   SDL_Color(0, 255, 0, 255),
                   SDL_FPoint(0))
	];

    while (true)
    {
        SDL_Event event;
        while (SDL_PollEvent(&event))
        {
            if (event.type == SDL_QUIT)
            {
                return 0;
            }
        }

        SDL_SetRenderDrawColor(renderer, 0, 0, 0, SDL_ALPHA_OPAQUE);
        SDL_RenderClear(renderer);
        SDL_RenderGeometry(renderer, null, vertices.ptr, vertices.length,
                           null, 0);
        SDL_RenderPresent(renderer);
    }
}


// serialport docs: https://code.dlang.org/packages/serialport
// API reference: http://serialport.dpldocs.info/serialport.html
int createSerialPortApp(string portPath)
{
    auto port = new SerialPortNonBlk(portPath, 9600);
    // On scope exit, close the handle to the port
    scope (exit) port.close();

    // Ask the device what the current state is
    port.write(['?']);
    while (true)
    {
        // Read 1 byte from the port. Note that port.read() is a blocking
        // call. In order to read from both, you need to use something like
        // select (note though that this is not available on Windows):
        // https://man7.org/linux/man-pages/man2/select.2.html,
        // https://en.wikipedia.org/wiki/Select_(Unix)
        byte[1] buffer;
        auto readBytes = cast(byte[]) port.read(buffer);

        // If the read returned length 0, the port has closed (device was
        // disconnected)
        if (readBytes.length == 0)
        {
            writeln("Device disconnected.");
            return 3;
        }

        if (readBytes[0] == 1)
        {
            writeln("Device wrote a 1.");
        }
    }
}

int main()
{
    write("Do you want to start the SDL app or the serial port app (sdl/serial)? ");
    auto selected = readln();

    if (selected == "sdl\n")
    {
        return createSDLApp();
    }
    else if (selected == "serial\n")
    {
        write("Enter a serial port path: ");
        auto portPathInput = readln();
        if (portPathInput.length < 2)
        {
            writeln("Invalid serial port path.");
            return 2;
        }

        // Chop off the newline character
        auto portPath = portPathInput[0 .. portPathInput.length - 1];
        return createSerialPortApp(portPath);
    }

    writeln("Invalid option.");
    return 1;
}
