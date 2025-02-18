import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../domain/models/activity_model.dart';
import '../../domain/models/submission_model.dart';
import '../../domain/models/enrolled_student_model.dart';

class StatisticsView extends StatelessWidget {
  final List<ActivityModel> activities;
  final List<EnrolledStudent> students;
  final List<Submission> submissions;

  const StatisticsView({
    super.key,
    required this.activities,
    required this.students,
    required this.submissions,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estadísticas del curso',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          
          // Tarjetas de resumen
          _buildSummaryCards(),
          const SizedBox(height: 24),

          // Gráfico de entregas por actividad
          _buildSubmissionsChart(),
          const SizedBox(height: 24),

          // Gráfico de distribución de notas
          _buildGradesDistributionChart(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalSubmissions = submissions.length;
    final totalPossibleSubmissions = activities.length * students.length;
    final gradedSubmissions = submissions.where((s) => s.calificacion != null).length;
    final submissionRate = totalPossibleSubmissions > 0 
        ? (totalSubmissions / totalPossibleSubmissions * 100).toStringAsFixed(1)
        : '0';
    
    final averageGrade = submissions.isEmpty ? 0.0 : 
        submissions.fold<double>(0, (sum, s) => sum + (s.calificacion ?? 0)) / submissions.length;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          title: 'Tasa de entregas',
          value: '$submissionRate%',
          icon: Icons.assignment_turned_in,
        ),
        _StatCard(
          title: 'Entregas calificadas',
          value: gradedSubmissions.toString(),
          icon: Icons.grading,
        ),
        _StatCard(
          title: 'Nota media',
          value: averageGrade.toStringAsFixed(1),
          icon: Icons.grade,
        ),
        _StatCard(
          title: 'Total actividades',
          value: activities.length.toString(),
          icon: Icons.assignment,
        ),
        _StatCard(
          title: 'Estudiantes',
          value: students.length.toString(),
          icon: Icons.people,
        ),
      ],
    );
  }

  Widget _buildSubmissionsChart() {
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: students.length.toDouble(),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= activities.length) return const Text('');
                  return Text(
                    'Act ${value.toInt() + 1}',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: _createBarGroups(),
        ),
      ),
    );
  }

  List<BarChartGroupData> _createBarGroups() {
    return List.generate(activities.length, (index) {
      final submissionsForActivity = submissions
          .where((s) => s.actividadId == activities[index].id)
          .length;
      
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: submissionsForActivity.toDouble(),
            color: Colors.blue,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });
  }

  Widget _buildGradesDistributionChart() {
    // Definimos rangos de notas de 0 a 10
    final gradeRanges = [0, 2, 4, 6, 8, 10];
    final distribution = List<int>.filled(gradeRanges.length - 1, 0);

    // Contamos las notas en cada rango
    for (var submission in submissions) {
      if (submission.calificacion != null) {
        for (var i = 0; i < gradeRanges.length - 1; i++) {
          if (submission.calificacion! >= gradeRanges[i] && 
              submission.calificacion! <= gradeRanges[i + 1]) {
            distribution[i]++;
            break;
          }
        }
      }
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0, // Aseguramos que no haya valores negativos
          maxY: distribution.reduce((a, b) => a > b ? a : b).toDouble() + 1,
          gridData: const FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 1,
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= gradeRanges.length - 1) return const Text('');
                  return Text(
                    '${gradeRanges[value.toInt()]}-${gradeRanges[value.toInt() + 1]}',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 30,
              ),
            ),

            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(distribution.length, (index) {
                return FlSpot(index.toDouble(), distribution[index].toDouble());
              }),
              isCurved: false, // Cambiado a false para una representación más precisa
              color: Colors.blue,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 