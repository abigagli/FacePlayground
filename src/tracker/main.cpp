#include <iostream>
#include <vector>
#include <string>
#include <cstdint>
#include <map>
#include <type_traits>
#include <memory>
#include <cassert>

#include "LuxandFaceSDK.h"
#include "license.h"

int main(int argc, char *argv[])
{
	if (FSDK_ActivateLibrary(license.c_str())  != FSDKE_OK)
	{
        std::cerr << "Error activating FaceSDK" << std::endl;
        std::cerr << "Please run the License Key Wizard (Start - Luxand - FaceSDK - License Key Wizard)" << std::endl;
		return -1;
	}
	FSDK_Initialize("");

	HImage ImageHandle;
	if (FSDK_LoadImageFromFile(&ImageHandle, argv[1]) != FSDKE_OK)
	{
        std::cerr << "Error loading file" << std::endl;
		return -1;
	}

    return 0;
}
