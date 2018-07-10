import java.io.*;
import java.util.Arrays;
import java.util.stream.IntStream;
import java.util.stream.DoubleStream;
//import java.lang.Math;

public class NeuralNetwork{
	private double[][] input, bias, layer;
	private double[][][] weights;

	public static void main(String[] args){
		System.out.println("Welcome to the Neural Network\nAuthor: GCastilho");
		NeuralNetwork neuralNetwork = new NeuralNetwork();
		neuralNetwork.console();
	}

	public void console(){
		boolean keep = true;
		while(keep){
			System.out.printf("Network console: ");
			Console console = System.console();
			String[] consoleInput = console.readLine().split(" ");
			switch(consoleInput[0]){
				//Fazer proteção contra null pointer exception
				case("create"):
					network_create(consoleInput[1].split(","));
				break;
				case("use"):
					System.out.println("é use");
				break;
				case("think"):
					double[] networkOutput = network_think(Arrays.stream(consoleInput[1].split(",")).mapToDouble(Double::parseDouble).toArray());
					//Printa a saída da rede
					for(int i=0; i<networkOutput.length; ++i){
						System.out.printf("Neuron %d: %f\n", i, networkOutput[i]);
					}
					System.out.println();
				break;
				case("learn"):
					network_learn(consoleInput);
				break;
				case("exit"):
					keep = false;
				break;
				default:
					System.out.printf("Comando não reconhecido\n\n");
				break;
			}
		}
	}

	//Fazer um tratamento de erros
	private void network_create(String[] argArray){
		int[] args = Arrays.stream(argArray).mapToInt(Integer::parseInt).toArray();
		int size = args.length;
		System.out.println("Layers: " + size); //Size mínimo deve ser 3
		//Cria as matrizes de todos os inputs e dos layers 
		//Cada célula do array de layers conterá um array com o número de células que foi especificado nos argumentos
		input = new double[size][];
		layer = new double[size][];
		for(int layerNum=0; layerNum<size; ++layerNum){
			layer[layerNum] = new double[args[layerNum]];
		}
		//Cria as matrizes dos weights e dos bias
		//As matrizes dos weights são no formato MxN, sendo M os neurônios da camada seguinte e N os neurônios da camada anteriror
		weights = new double[size][][];
		bias = new double[size][];
		for(int layerNum=1; layerNum<size; ++layerNum){
			weights[layerNum] = new double[args[layerNum]][args[layerNum-1]];
			bias[layerNum] = new double[args[layerNum]];
		}
		//Prenche os biases com 0
		//Nota, o código atualmente usa bias por neurônio ao invés de por layer, eu não sei qual deles normalmente se usa, mas ambos são possíveis
		for(int m=1; m<bias.length; ++m){
			for(int n=0; n<bias[m].length; ++n){
				bias[m][n] = 0.0;
			}
		}
		//Preenche os valores dos weights com valores aleatórios de -5 a 5 e diferentes de 0
		for(int layerNum=1; layerNum<weights.length; ++layerNum){
			for(int m=0; m<weights[layerNum].length; ++m){
				for(int n=0; n<weights[layerNum][m].length; ++n){
					weights[layerNum][m][n] = 0.0;
					while(weights[layerNum][m][n] == 0){
						weights[layerNum][m][n] = Math.random() * 10 - 5;
					}
				}
			}
		}
	}

	//public void network_think(String nName, double[] data){ //substituír arg por nName, que é setado no create e use
	public double[] network_think(double[] args){
		if(layer[0].length != args.length){
			System.out.printf("Tamanho de entrada incorreta\n"); double[] empty = {}; return(empty);
		}
		layer[0] = args;
		for(int i=1; i<layer.length; ++i){
			input[i] = multiply(weights[i], layer[i-1]);	//Calcula Z
			for(int j=0; j<layer[i].length; ++j){
				layer[i][j] = nonLinear(input[i][j]);		//Passa todos os Z do layer i por uma função não linear (activation function)
			}
		}
		return(layer[layer.length-1]);						//Retorna a saída do último neurônio em um array
	}

	public void network_learn(String[] argArray){
		//Esse modo de organizar o learnSet é temporário, já que ele é feito para entrada manual de dados
		//os dados do learnSet[i][0][k] são os testes e o learnSet[i][1][k] são as respostas dos testes (target), pra cada neurônio
		double[][][] learnSet = new double[argArray.length][2][];
		for(int set=1; set<argArray.length; ++set){
			for(int j=0; j<2; ++j){
				learnSet[set][j] = new double[ argArray[set].split(";")[j].split(",").length ];
				for (int k=0; k<argArray[set].split(";")[j].split(",").length; ++k){
					learnSet[set][j][k] = Double.parseDouble(argArray[set].split(";")[j].split(",")[k]);
				}
			}
		}
		double[][] sigma = new double[layer.length][];
		double[][][] adjustmentWeight = new double[layer.length][][];
		int iteractions = 1000;
		System.out.printf("Looping for %d times\nLearning... ", iteractions);
		for(int count=1; count<=iteractions; ++count){
			double totalError = 0.0;
			if(count == 1 || count % 100 == 0){ System.out.printf("\nRunning %d... ", count); }
			//create adjustmentWeight matrix on each layerNum
			for(int layerNum=layer.length-1; 0<layerNum; --layerNum){
				adjustmentWeight[layerNum] = new double[weights[layerNum].length][weights[layerNum][0].length];	//create MxN matrix in aW[layerNum]
				//Reset adjustmentWeight
				for(int j=0; j<adjustmentWeight[layerNum].length; ++j){
					for(int k=0; k<adjustmentWeight[layerNum][j].length; ++k){
						adjustmentWeight[layerNum][j][k] = 0.0;
					}
				}
			}
			//Treina a network com o set de testes passados como argumento
			for(int set=1; set<argArray.length; ++set){
				double[] output = network_think(learnSet[set][0]);
				double[] error = new double[output.length];
				for(int neuron=0; neuron<output.length; ++neuron){
					error[neuron] = output[neuron] - learnSet[set][1][neuron];
				}
				totalError += Math.abs(DoubleStream.of(error).sum()/output.length);
				//Backpropagation
				//Sigma of last neuron
				sigma[layer.length-1] = new double[output.length];
				for(int neuron=0; neuron<output.length; ++neuron){
					sigma[layer.length-1][neuron] = error[neuron] * nonLinearDerivative(input[input.length-1][neuron]);
				}
				//Sigma of the others neurons
				for(int layerNum=layer.length-2; 0<layerNum; --layerNum){
					sigma[layerNum] = multiply(transposeMatrix(weights[layerNum+1]), sigma[layerNum+1]);
					for(int neuron=0; neuron<sigma[layerNum].length; ++neuron){
						sigma[layerNum][neuron] = sigma[layerNum][neuron] * nonLinearDerivative(input[layerNum][neuron]);
					}
				}
				//Calculate adjustment weights
				for(int layerNum=layer.length-1; 0<layerNum; --layerNum){
					for(int m=0; m<weights[layerNum].length; ++m){
						for(int n=0; n<weights[layerNum][0].length; ++n){
							adjustmentWeight[layerNum][m][n] -= multiply(sigma[layerNum], layer[layerNum-1])[m][n];
						}
					}
				}
			}
			//Update the weights considering all the trainings sets
			for(int layerNum=layer.length-1; 0<layerNum; --layerNum){
				for(int m=0; m<weights[layerNum].length; ++m){
					for(int n=0; n<weights[layerNum][0].length; ++n){
						weights[layerNum][m][n] += adjustmentWeight[layerNum][m][n];
					}
				}
			}
			//Show error value
			totalError = totalError/(argArray.length-1);
			if(count == 1 || count % 100 == 0){ System.out.printf("Learn set error: %f", totalError); }
			if(totalError<0.001){
				System.out.printf("\nRunning %d... Learn set error: %f", count, totalError);
				break;
			}
		}
		System.out.println("\nDone");
	}

	public static double nonLinear(double x){
		return(1/( 1 + Math.pow(Math.E,(-1*x))));
	}

	public static double nonLinearDerivative(double x){
		double sigmoid = nonLinear(x);
		return(sigmoid*(1-sigmoid));
	}

	public static double[] multiply(double[][] matrix, double[] vector){
		return(Arrays.stream(matrix).mapToDouble(row -> IntStream.range(0, row.length).mapToDouble(col -> row[col] * vector[col]).sum()).toArray());
	}

	public static double[][] multiply(double[] a, double[] b){
		double[][] matrix = new double[a.length][b.length];
		for(int m = 0; m<a.length; ++m){
			for(int n = 0; n<b.length; ++n){
				matrix[m][n] = a[m] * b[n];
			}
		}
		return(matrix);
	}

	public static double[][] transposeMatrix(double[][] m){
		double[][] matrix = new double[m[0].length][m.length];
		for(int i = 0; i < m.length; ++i){
			for(int j = 0; j < m[0].length; ++j){
				matrix[j][i] = m[i][j];
			}
		}
		return(matrix);
	}
}