#include <iostream> // Para std::cout y std::endl
#include <unistd.h> // Para fork(), getpid(), getppid()
#include <cstdlib>  // Para exit()

using namespace std;

// Declaración de funciones
pid_t crear_hijo();
pid_t crear_demonio();

int main(int argc, char *argv[]) {
    cout << "Soy el padre con PID " << getpid() << endl;

    pid_t hijo_1 = crear_hijo();

    #pragma region primer hijo
    if (hijo_1 == 0) {
        // Código del primer hijo
        cout << "Soy el hijo 1 con PID " << getpid()
             << "\tMi padre es " << getppid() << endl;

        for (int i = 0; i < 2; i++) {
            pid_t nieto = crear_hijo();
            if (nieto == 0) {
                cout << "Soy el nieto " << (i + 1) << " con PID " << getpid()
                     << "\tMi padre es " << getppid() << endl;
                return 0;
            }
        }

        pid_t zombie = crear_hijo();
        if (zombie == 0) {
            cout << "Soy el zombie con PID " << getpid() << "\tMi padre es " << getppid() << endl;
            exit(0); // Salida inmediata para dejar el zombie
        }

        return 0;
    }
    #pragma endregion primer hijo

    pid_t hijo_2 = crear_hijo();

    #pragma region segundo hijo
    if (hijo_2 == 0) {
        // Código del segundo hijo

        cout << "Soy el hijo 2 con PID " << getpid()
             << "\tMi padre es " << getppid() << endl;

        pid_t demonio = crear_demonio();
        if (demonio == 0) {
            cout << "Soy el demonio con PID " << getpid() << "\tMi padre era " << getppid() << endl;

            // Simular que el demonio hace algo
            while (true) {
                sleep(10); // El demonio se queda ejecutando
            }
        }
    }
    #pragma endregion segundo hijo

    return 0;
}

// Función para crear un hijo
pid_t crear_hijo() {
    pid_t hijo = fork();

    if (hijo < 0) {
        perror("Error al crear el hijo");
        exit(1);
    }

    return hijo;
}

// Función para crear un demonio
pid_t crear_demonio() {
    pid_t pid = fork();

    if (pid < 0) {
        perror("Error al crear el demonio");
        exit(1);
    }
    if (pid > 0) {
        // Proceso padre termina
        exit(0);
    }

    // Proceso hijo continúa y se convierte en demonio
    if (setsid() < 0) {
        perror("Error al crear la nueva sesión");
        exit(1);
    }

    // Redirigir stdin, stdout y stderr a /dev/null
    freopen("/dev/null", "r", stdin);
    freopen("/dev/null", "w", stdout);
    freopen("/dev/null", "w", stderr);

    return 0; // El demonio no debe devolver nada útil en este caso
}
