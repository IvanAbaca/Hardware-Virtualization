#include <iostream> // Para std::cout y std::endl
#include <unistd.h> // Para fork(), getpid(), getppid()
#include <cstdlib>  // Para exit()
#include <sys/wait.h>

#include <fstream> // Para std::ofstream
#include <string>  // Para std::string
#include <ctime>   // Para obtener la hora actual

using namespace std;

// Declaración de funciones
pid_t crear_hijo();
pid_t crear_demonio();
void escribir_log(const std::string& mensaje, const std::string& filename);

int main(int argc, char *argv[]) {
    int status;

    pid_t hijo1 = crear_hijo();

    if(hijo1 == 0) {
        cout<<getpid()<<"(hijo1) es hijo de "<<getppid()<<"(padre)"<<endl;

        pid_t nieto1 = crear_hijo();
        if(nieto1 == 0) {
            cout<<getpid()<<"(nieto1) es hijo de "<<getppid()<<"(hijo1)"<<endl;
            cin.get();
        }
        else {
            pid_t zombie = crear_hijo();
            if(zombie == 0) {
                cout<<getpid()<<"(zombie) es hijo de "<<getppid()<<"(hijo1)"<<endl;
            }
            else {
                pid_t nieto2 = crear_hijo();
                if(nieto2 == 0) {
                    cout<<getpid()<<"(nieto2) es hijo de "<<getppid()<<"(hijo1)"<<endl;
                    cin.get();
                }
                else {
                    waitpid(nieto1, &status, 0);
                    waitpid(nieto2, &status, 0);

                    cin.get();
                }
            }
        }
    }
    else {
        pid_t hijo2 = crear_hijo();
        
        if(hijo2 == 0) {
            cout<<getpid()<<"(hijo2) es hijo de "<<getppid()<<"(padre)"<<endl;

            pid_t demonio = crear_demonio();
            if(demonio == 0) {
                cout<<getpid()<<"(demonio) es hijo de "<<getppid()<<"(hijo2)"<<endl;
                std::string mensaje = std::to_string(getpid()) + "(demonio), el cual es independiente del padre.";
                escribir_log(mensaje, "demonio.log");
                sleep(5);
            }
            else {
                cin.get();
            }
        }
        else {
            waitpid(hijo2, &status, 0);
            waitpid(hijo1, &status, 0);

            cin.get();
        }
    }
    exit(0);
}

pid_t crear_hijo() {
    pid_t hijo = fork();

    if (hijo < 0) {
        perror("Error al crear el hijo");
        exit(1);
    }

    return hijo;
}

pid_t crear_demonio() {
    pid_t pid = fork();

    if (pid < 0)
        exit(1);

    if (setsid() < 0)
        exit(1);

    freopen("/dev/null", "r", stdin);
    freopen("/dev/null", "w", stdout);
    freopen("/dev/null", "w", stderr);

    return pid;
}

void escribir_log(const std::string& mensaje, const std::string& filename) {
    std::ofstream log_file(filename, std::ios::app);

    if (!log_file.is_open()) {
        std::cerr << "Error al abrir el archivo de log." << std::endl;
        return;
    }

    log_file << mensaje << std::endl;
    log_file.close();
}