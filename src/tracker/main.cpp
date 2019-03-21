#include <iostream>
#include <vector>
#include <string>
#include <cstdint>
#include <map>
#include <type_traits>
#include <memory>
#include <cassert>
#include <thread>
#include <atomic>
#include <signal.h>

#include "LuxandFaceSDK.h"
#include "license.h"

void usage (char *invocation)
{
    std::cerr << "USAGE: " << invocation << " [stream_ip = 127.0.0.1] [stream_port = 8080]";
}

namespace config
{
    std::string stream_ip = "127.0.0.1";
    int stream_port = 8080;
    std::string stream_id = "";
    std::string username;
    std::string userpwd;
    int timeout_seconds = 30;
}

namespace globals
{
    std::atomic<bool> keep_going(true);
}

bool parse_args (int argc, char *argv[])
{
    if (argc > 1)
        config::stream_ip = argv[1];

    if (argc > 2)
        config::stream_port = std::stoi(argv[2]);

    if (argc > 3)
        config::stream_id = argv[3];


    return true;
}

void sig_handler(int)
{
    std::clog << "SIGNAL RECEIVED\n";
    globals::keep_going = false;
}

bool initialize(char const *license)
{
    if (FSDK_ActivateLibrary(license) != FSDKE_OK)
    {
        std::cerr << "Error activating FaceSDK\n";
        return false;
    }

    char initialize_args[32];
    if (FSDK_Initialize(initialize_args) != FSDKE_OK)
    {
        std::cerr << "Error Initializing SDK\n";
        return false;
    }

    char license_info[512];
    if (FSDK_GetLicenseInfo(license_info) != FSDKE_OK)
    {
        std::cerr << "Error getting license info\n";
        return false;
    }

    std::cerr << "Detected license: " << license_info << "\n";

    int num_threads;
    if (FSDK_GetNumThreads (&num_threads) != FSDKE_OK)
    {
        std::cerr << "Error getting num threads\n";
        return false;
    }

    std::cerr << "Detected num_threads: " << num_threads << "\n";
    return true;
}

int main(int argc, char *argv[])
{
    signal (SIGINT, sig_handler);
    if (!parse_args(argc, argv))
    {
        usage(argv[0]);
        return -1;
    }

    if (!initialize(license.c_str()))
        return -2;


    HTracker tracker = 0;
    FSDK_CreateTracker(&tracker);

    int err = 0; // set realtime face detection parameters
    FSDK_SetTrackerMultipleParameters(tracker,
                                      "RecognizeFaces=true; \
                                       InternalResizeWidth=1024; \
                                       DetectFacialFeatures=true; \
                                       DetectGender=true; \
                                       DetectAge=true; \
                                       DetectExpression=true; \
                                       Learning=true; \
                                       MemoryLimit=2150; \
                                       KeepFaceImages=false; \
                                       HandleArbitraryRotations=true; \
                                       DetermineFaceRotationAngle=false; \
                                       FaceDetectionThreshold=3;",
                                      &err);

    int cameraHandle = 0;
    bool stream_connected = false;
    int frame_number = 0;

    while (globals::keep_going)
    {
        if (!stream_connected)
        {
            std::string camera_url = config::stream_ip + ":" + std::to_string(config::stream_port) + config::stream_id;
            std::clog << "Trying to connect to " << camera_url << std::endl;
            if (FSDKE_OK !=
                FSDK_OpenIPVideoCamera(FSDK_MJPEG, camera_url.c_str(), config::username.c_str(), config::userpwd.c_str(),
                                       config::timeout_seconds, &cameraHandle))
            {
                std::cerr << "Connection to stream failed. Retrying in 1 second\n";
                std::this_thread::sleep_for(std::chrono::seconds(1));
                continue;
            }

            std::clog << "Connected\n";
            stream_connected = true;
        }


        HImage imageHandle;
        int grab_res = FSDK_GrabFrame(cameraHandle, &imageHandle);
        if (grab_res != FSDKE_OK)
        {
            std::cerr << "Error " << grab_res << " in grabframe for frame_number " << frame_number << "\n";

            if (stream_connected)
            {
                std::cerr << "Trying to close stream\n";
                if (FSDKE_OK != FSDK_CloseVideoCamera(cameraHandle))
                {
                    std::cerr << "Error closing stream\n";
                    return -4;
                }

                std::cerr << "Stream closed\n";
                stream_connected = false;
            }

            continue;
        }

        //******* SAVE IMAGE *********
        //FSDK_SaveImageToFile(imageHandle, ("/tmp/image_" + std::to_string(frame_number) + ".jpg").c_str());

        long long IDs[256]{};
        long long faceCount = 0;

        FSDK_FeedFrame(tracker, 0, imageHandle, &faceCount, IDs, sizeof(IDs));



        int width;
        int height;
        FSDK_GetImageWidth(imageHandle, &width);
        FSDK_GetImageHeight(imageHandle, &height);

        std::clog << "frame " << frame_number << ": faceCount =  " << faceCount << ", width = " << width << ", height = " << height << ", IDS: ";

        for (auto i = 0U; (i < sizeof(IDs) / sizeof(decltype(IDs[0]))) && (IDs[i] != 0); ++i)
            std::clog << IDs[i] << "@" << i << ", ";


        std::clog << " | ";

        if (faceCount && IDs[0])
        {
            char gender[128];
            if (FSDKE_OK == FSDK_GetTrackerFacialAttribute(tracker, 0, IDs[0], "Gender", gender, sizeof(gender)))
                std::clog << ", gender=" << gender;

            char age[64];
            if (FSDKE_OK == FSDK_GetTrackerFacialAttribute(tracker, 0, IDs[0], "Age", age, sizeof(age)))
                std::clog << ", age=" << age;

            char expression[128];
            if (FSDKE_OK == FSDK_GetTrackerFacialAttribute(tracker, 0, IDs[0], "Expression", expression, sizeof(expression)))
                std::clog << ", expression=" << expression;

            /*
             *char attributes[256];
             *if (FSDKE_OK == FSDK_GetTrackerFacialAttribute(tracker, 0, IDs[0], "Gender; Age; Expression", attributes, sizeof(attributes)))
             *    std::clog << ", attributes=" << attributes;
             */

        }

        long long trackerBufSize;
        FSDK_GetTrackerMemoryBufferSize (tracker, &trackerBufSize);
        std::clog << ", trackerMemSize=" << trackerBufSize;
        std::clog << "\n";
        /*
        HImage resizedImageHandle;
        FSDK_CreateEmptyImage(&resizedImageHandle);

        float ratio = 1.5;
        FSDK_ResizeImage(imageHandle, ratio, resizedImageHandle);
        FSDK_FreeImage(imageHandle);

        FSDK_GetImageWidth(resizedImageHandle, &width);
        FSDK_GetImageWidth(resizedImageHandle, &height);

         */

        FSDK_FreeImage(imageHandle);

        //std::this_thread::sleep_for(std::chrono::milliseconds(10));
        ++frame_number;
    }

    if (stream_connected  && (FSDKE_OK != FSDK_CloseVideoCamera(cameraHandle)))
    {
        std::cerr << "Error closing stream\n";
        return -3;
    }

    std::clog << "Stream closed\n";
    FSDK_Finalize();
    return 0;
}
