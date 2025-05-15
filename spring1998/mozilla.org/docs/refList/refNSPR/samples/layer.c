/* Copyright © 1998 Netscape Communications Corporation */

#include "prio.h"
#include "prprf.h"
#include "prlog.h"
#include "prnetdb.h"
#include "prthread.h"
#include "prinit.h"
typedef enum Verbosity {silent, quiet, chatty, noisy} Verbosity;

static PRFileDesc *logFile;
static PRDescIdentity identity;
static PRNetAddr server_address;
static Verbosity verbosity = chatty;
static PRUint16 default_port = 12273;

static void PR_CALLBACK Client(void *arg);
static void PR_CALLBACK Server(void *arg);
static PRFileDesc *PopLayer(PRFileDesc *stack);
static PRFileDesc *PushLayer(PRFileDesc *stack);

PRIntn main(PRIntn argc, char **argv)
{
    PRStatus rv;
    PRFileDesc *client, *service;
    const char *server_name = NULL;
    PRThread *client_thread, *server_thread;
    PRThreadScope thread_scope = PR_LOCAL_THREAD;

/* The PR_SDIO_INIT() macro handles differences between systems */
/* that define a console I/O facility and those that don't. */
    PR_STDIO_INIT();
    logFile = PR_GetSpecialFD(PR_StandardError);

    identity = PR_GetUniqueIdentity("Dummy");
/* Following lines isolate code from differences between IPv4 and IPv6. */
    if (NULL == server_name)
        rv = PR_InitializeNetAddr(
            PR_IpAddrLoopback, default_port, &server_address);
    else
    {
        rv = PR_StringToNetAddr(server_name, &server_address);
        PR_ASSERT(PR_SUCCESS == rv);
        rv = PR_InitializeNetAddr(
            PR_IpAddrNull, default_port, &server_address);
    }
    PR_ASSERT(PR_SUCCESS == rv);

    if (verbosity > silent)
        PR_fprintf(logFile, "Beginning layered test\n");

/* Create new network file descriptors. */
    client = PR_NewTCPSocket(); PR_ASSERT(NULL != client);
    service = PR_NewTCPSocket(); PR_ASSERT(NULL != service);

/* Create new server and client threads */
    server_thread = PR_CreateThread(
        PR_USER_THREAD, Server, PushLayer(service),
        PR_PRIORITY_HIGH, thread_scope,
        PR_JOINABLE_THREAD, 16 * 1024);
    PR_ASSERT(NULL != server_thread);
    client_thread = PR_CreateThread(
        PR_USER_THREAD, Client, PushLayer(client),
        PR_PRIORITY_NORMAL, thread_scope,
        PR_JOINABLE_THREAD, 16 * 1024);
    PR_ASSERT(NULL != client_thread);
/* Synchronize termination of calling thread with the termination of client and server threads */
    rv = PR_JoinThread(client_thread);
    PR_ASSERT(PR_SUCCESS == rv);
    rv = PR_JoinThread(server_thread);
    PR_ASSERT(PR_SUCCESS == rv);

    rv = PR_Close(PopLayer(client)); PR_ASSERT(PR_SUCCESS == rv);
    rv = PR_Close(PopLayer(service)); PR_ASSERT(PR_SUCCESS == rv);
    if (verbosity > silent)
        PR_fprintf(logFile, "Ending layered test\n");
    return 0;
}  /* main */

static PRFileDesc *PushLayer(PRFileDesc *stack)
{
    PRFileDesc *layer = PR_CreateIOLayerStub(identity, PR_GetDefaultIOMethods());
    PRStatus rv = PR_PushIOLayer(stack, PR_GetLayersIdentity(stack), layer);

    if (verbosity > quiet)
        PR_fprintf(logFile, "Pushed layer(0x%x) onto stack(0x%x)\n", layer, stack);
    PR_ASSERT(PR_SUCCESS == rv);
    return layer;
}  /* PushLayer */

static PRFileDesc *PopLayer(PRFileDesc *stack)
{
    PRFileDesc *popped = PR_PopIOLayer(stack, identity);

    if (verbosity > quiet)
        PR_fprintf(logFile, "Popped layer(0x%x) from stack(0x%x)\n", popped, stack);
    popped->dtor(popped);

    return stack;
}  /* PopLayer */

static void PR_CALLBACK Client(void *arg)
{
    PRStatus rv;
    PRUint8 buffer[100];
    PRIntn empty_flags = 0;
    PRIntn bytes_read, bytes_sent;
    PRFileDesc *stack = (PRFileDesc*)arg;
/* Bind the address to the connection and establish the virtual circuit to the peer. */
    rv = PR_Connect(stack, &server_address, PR_INTERVAL_NO_TIMEOUT);
    PR_ASSERT(PR_SUCCESS == rv);

/* Send operations either transmit all the data or fail before returning. */
    bytes_sent = PR_Send(
        stack, buffer, sizeof(buffer), empty_flags, PR_INTERVAL_NO_TIMEOUT);
    PR_ASSERT(sizeof(buffer) == bytes_sent);

    if (verbosity > chatty)
        PR_fprintf(logFile, "Client sending %d bytes\n", bytes_sent);

    bytes_read = PR_Recv(
        stack, buffer, bytes_sent, empty_flags, PR_INTERVAL_NO_TIMEOUT);
    if (verbosity > chatty)
        PR_fprintf(logFile, "Client receiving %d bytes\n", bytes_read);
    PR_ASSERT(bytes_read == bytes_sent);
    if (verbosity > quiet)
        PR_fprintf(logFile, "Client shutting down stack\n");

/* Once the exchange has been accomplished, the transport is shut down. */
    rv = PR_Shutdown(stack, PR_SHUTDOWN_BOTH); PR_ASSERT(PR_SUCCESS == rv);
}  /* Client */

static void PR_CALLBACK Server(void *arg)
{
    PRStatus rv;
    PRUint8 buffer[100];
    PRFileDesc *service;
    PRUintn empty_flags = 0;
    PRIntn bytes_read, bytes_sent;
    PRFileDesc *stack = (PRFileDesc*)arg;
    PRNetAddr any_address, client_address;

    rv = PR_InitializeNetAddr(PR_IpAddrAny, default_port, &any_address);
    PR_ASSERT(PR_SUCCESS == rv);
    rv = PR_Bind(stack, &any_address); PR_ASSERT(PR_SUCCESS == rv);
    rv = PR_Listen(stack, 10); PR_ASSERT(PR_SUCCESS == rv);
    service = PR_Accept(stack, &client_address, PR_INTERVAL_NO_TIMEOUT);
    if (verbosity > quiet)
        PR_fprintf(logFile, "Server accepting connection\n");

    do
    {
        bytes_read = PR_Recv(
            service, buffer, sizeof(buffer), empty_flags, PR_INTERVAL_NO_TIMEOUT);
        if (0 != bytes_read)
        {
            if (verbosity > chatty)
                PR_fprintf(logFile, "Server receiving %d bytes\n", bytes_read);
            PR_ASSERT(bytes_read > 0);
            bytes_sent = PR_Send(
                service, buffer, bytes_read, empty_flags, PR_INTERVAL_NO_TIMEOUT);
            if (verbosity > chatty)
                PR_fprintf(logFile, "Server sending %d bytes\n", bytes_sent);
            PR_ASSERT(bytes_read == bytes_sent);
        }
    } while (0 != bytes_read);

    if (verbosity > quiet)
        PR_fprintf(logFile, "Server shutting down and closing stack\n");
    rv = PR_Shutdown(service, PR_SHUTDOWN_BOTH); PR_ASSERT(PR_SUCCESS == rv);
    rv = PR_Close(service); 
    PR_ASSERT(PR_SUCCESS == rv);
}  /* Server */

/* layer.c */
