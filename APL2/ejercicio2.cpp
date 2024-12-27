#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <dirent.h>

// Recursos compartidos
char* archivos[100]; // Array de archivos (máximo 100 archivos para simplicidad)
int total_archivos = 0; // Número total de archivos
int archivo_actual = 0; // Índice del archivo actual

// Mutex para proteger el acceso al recurso compartido
pthread_mutex_t mutex;

// Cadena a buscar
const char* cadena_a_buscar = "buscar";

// Función para procesar un archivo (simulación)
void procesar_archivo(const char* archivo, int thread_id) {
    FILE* file = fopen(archivo, "r");
    if (!file) {
        printf("Thread %d: No se pudo abrir el archivo %s\n", thread_id, archivo);
        return;
    }

    char linea[1024];
    int numero_linea = 0;

    while (fgets(linea, sizeof(linea), file)) {
        numero_linea++;
        if (strstr(linea, cadena_a_buscar)) {
            printf("Thread %d: Archivo: %s, Línea: %d\n", thread_id, archivo, numero_linea);
        }
    }

    fclose(file);
}

// Función que ejecutan los threads
void* thread_func(void* arg) {
    int thread_id = *(int*)arg;

    while (1) {
        pthread_mutex_lock(&mutex);

        // Si no quedan más archivos, liberar el mutex y salir
        if (archivo_actual >= total_archivos) {
            pthread_mutex_unlock(&mutex);
            break;
        }

        // Obtener el archivo actual y avanzar el índice
        char* archivo = archivos[archivo_actual];
        archivo_actual++;

        pthread_mutex_unlock(&mutex);

        // Procesar el archivo
        procesar_archivo(archivo, thread_id);
    }

    return NULL;
}

// Función para listar los archivos en el directorio
void listar_archivos(const char* directorio) {
    DIR* dir = opendir(directorio);
    if (!dir) {
        perror("No se pudo abrir el directorio");
        exit(EXIT_FAILURE);
    }

    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        // Ignorar "." y ".."
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        // Construir la ruta completa del archivo
        char* ruta = (char*)malloc(1024);
        snprintf(ruta, 1024, "%s/%s", directorio, entry->d_name);

        archivos[total_archivos++] = ruta;
    }

    closedir(dir);
}

int main() {
    const char* directorio = "./Ejercicio2"; // Directorio relativo
    int num_threads = 3; // Número de threads

    // Listar los archivos en el directorio
    listar_archivos(directorio);

    // Inicializar el mutex
    pthread_mutex_init(&mutex, NULL);

    // Crear los threads
    pthread_t threads[num_threads];
    int thread_ids[num_threads];

    for (int i = 0; i < num_threads; i++) {
        thread_ids[i] = i + 1;
        pthread_create(&threads[i], NULL, thread_func, &thread_ids[i]);
    }

    // Esperar a que terminen los threads
    for (int i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }

    // Destruir el mutex
    pthread_mutex_destroy(&mutex);

    // Liberar la memoria de los nombres de los archivos
    for (int i = 0; i < total_archivos; i++) {
        free(archivos[i]);
    }

    printf("Procesamiento terminado.\n");

    return 0;
}
