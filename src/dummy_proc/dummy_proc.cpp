#include <iostream>
#include <chrono>
#include <thread>

#pragma comment(linker, "/subsystem:\"windows\" /entry:\"mainCRTStartup\"")

int main()
{
	for(;;)
	{
		std::this_thread::sleep_for(std::chrono::milliseconds(100));
	}
}
